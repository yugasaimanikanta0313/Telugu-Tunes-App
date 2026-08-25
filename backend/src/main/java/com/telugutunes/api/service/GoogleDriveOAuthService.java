package com.telugutunes.api.service;

import com.google.api.client.http.HttpRequest;
import com.google.api.client.http.HttpRequestInitializer;
import com.google.auth.http.HttpCredentialsAdapter;
import com.google.auth.oauth2.UserCredentials;
import com.telugutunes.api.config.AppProperties;
import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest.BodyPublishers;
import java.net.http.HttpResponse.BodyHandlers;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;
import org.springframework.stereotype.Service;
import tools.jackson.databind.ObjectMapper;

/**
 * Completes the one-time OAuth approval for the owner's Google Drive, then uses the locally saved
 * refresh token to authorize Drive requests. No Drive credential is sent to the Flutter app.
 */
@Service
@org.springframework.boot.autoconfigure.condition.ConditionalOnExpression(
    "'${app.storage.google-drive.enabled:false}' == 'true' && '${app.storage.google-drive.mode:oauth}' == 'oauth'")
public class GoogleDriveOAuthService implements HttpRequestInitializer {
  private static final String DRIVE_FILE_SCOPE = "https://www.googleapis.com/auth/drive.file";
  private static final URI TOKEN_URI = URI.create("https://oauth2.googleapis.com/token");

  private final AppProperties properties;
  private final ObjectMapper objectMapper = new ObjectMapper();
  private final HttpClient httpClient = HttpClient.newHttpClient();
  private final SecureRandom secureRandom = new SecureRandom();
  private final AtomicReference<String> pendingState = new AtomicReference<>();

  public GoogleDriveOAuthService(AppProperties properties) {
    this.properties = properties;
  }

  public String authorizationUrl() throws IOException {
    var client = clientConfig();
    var state = new byte[32];
    secureRandom.nextBytes(state);
    var encodedState = Base64.getUrlEncoder().withoutPadding().encodeToString(state);
    pendingState.set(encodedState);

    var parameters = new LinkedHashMap<String, String>();
    parameters.put("client_id", client.clientId());
    parameters.put("redirect_uri", redirectUri());
    parameters.put("response_type", "code");
    parameters.put("scope", DRIVE_FILE_SCOPE);
    parameters.put("access_type", "offline");
    parameters.put("prompt", "consent");
    parameters.put("state", encodedState);
    return "https://accounts.google.com/o/oauth2/v2/auth?" + form(parameters);
  }

  public void completeAuthorization(String code, String state) throws IOException, InterruptedException {
    var expectedState = pendingState.getAndSet(null);
    if (expectedState == null || !constantTimeEquals(expectedState, state)) {
      throw new IllegalArgumentException("The Google Drive connection link is invalid or has expired.");
    }

    var client = clientConfig();
    var parameters = new LinkedHashMap<String, String>();
    parameters.put("code", code);
    parameters.put("client_id", client.clientId());
    parameters.put("client_secret", client.clientSecret());
    parameters.put("redirect_uri", redirectUri());
    parameters.put("grant_type", "authorization_code");

    var request =
        java.net.http.HttpRequest.newBuilder(TOKEN_URI)
            .header("Content-Type", "application/x-www-form-urlencoded")
            .POST(BodyPublishers.ofString(form(parameters)))
            .build();
    var response = httpClient.send(request, BodyHandlers.ofString());
    if (response.statusCode() < 200 || response.statusCode() >= 300) {
      throw new IOException("Google did not approve the Drive connection. Please try again.");
    }

    var refreshToken = objectMapper.readTree(response.body()).path("refresh_token").asText(null);
    if (refreshToken == null || refreshToken.isBlank()) {
      throw new IOException("Google did not return a reusable Drive authorization. Please try again.");
    }
    var tokenPath = tokenPath();
    var parent = tokenPath.getParent();
    if (parent != null) {
      Files.createDirectories(parent);
    }
    objectMapper.writeValue(tokenPath.toFile(), Map.of("refresh_token", refreshToken));
  }

  public boolean isConnected() {
    try {
      var token = loadStoredToken();
      return Files.isRegularFile(tokenPath())
          && token.refreshToken() != null
          && !token.refreshToken().isBlank();
    } catch (IOException | RuntimeException exception) {
      return false;
    }
  }

  @Override
  public void initialize(HttpRequest request) throws IOException {
    new HttpCredentialsAdapter(userCredentials()).initialize(request);
  }

  private UserCredentials userCredentials() throws IOException {
    if (!isConnected()) {
      throw new IOException(
          "Google Drive is not connected. Open /api/v1/storage/google-drive/connect on this computer first.");
    }
    var client = clientConfig();
    var token = loadStoredToken();
    return UserCredentials.newBuilder()
        .setClientId(client.clientId())
        .setClientSecret(client.clientSecret())
        .setRefreshToken(token.refreshToken())
        .build();
  }

  private OAuthClientConfig clientConfig() throws IOException {
    var path = properties.getStorage().getGoogleDrive().getOauthClientJson();
    if (path == null || path.isBlank()) {
      throw new IOException("Set app.storage.google-drive.oauth-client-json before connecting Google Drive.");
    }
    var web = objectMapper.readTree(Path.of(path).toFile()).path("web");
    var clientId = web.path("client_id").asText(null);
    var clientSecret = web.path("client_secret").asText(null);
    if (clientId == null
        || clientSecret == null
        || clientId.isBlank()
        || clientSecret.isBlank()) {
      throw new IOException("The OAuth client file must be a Google web application client JSON file.");
    }
    return new OAuthClientConfig(clientId, clientSecret);
  }

  private StoredRefreshToken loadStoredToken() throws IOException {
    return new StoredRefreshToken(
        objectMapper.readTree(tokenPath().toFile()).path("refresh_token").asText(null));
  }

  private Path tokenPath() throws IOException {
    var path = properties.getStorage().getGoogleDrive().getOauthTokenJson();
    if (path == null || path.isBlank()) {
      throw new IOException("Set app.storage.google-drive.oauth-token-json before connecting Google Drive.");
    }
    return Path.of(path);
  }

  private String redirectUri() {
    return properties.getStorage().getGoogleDrive().getOauthRedirectUri();
  }

  private String form(Map<String, String> values) {
    return values.entrySet().stream()
        .map(entry -> encode(entry.getKey()) + "=" + encode(entry.getValue()))
        .reduce((left, right) -> left + "&" + right)
        .orElse("");
  }

  private String encode(String value) {
    return URLEncoder.encode(value, StandardCharsets.UTF_8);
  }

  private boolean constantTimeEquals(String left, String right) {
    return right != null
        && java.security.MessageDigest.isEqual(
            left.getBytes(StandardCharsets.UTF_8), right.getBytes(StandardCharsets.UTF_8));
  }

  private record OAuthClientConfig(String clientId, String clientSecret) {}

  private record StoredRefreshToken(String refreshToken) {}
}
