package com.telugutunes.api.config;

import java.util.ArrayList;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app")
public class AppProperties {
  private final Cors cors = new Cors();
  private final Storage storage = new Storage();
  private final Gemini gemini = new Gemini();
  private final Groq groq = new Groq();
  private final YouTube youtube = new YouTube();
  private final Access access = new Access();
  private final Lyrics lyrics = new Lyrics();

  public Cors getCors() {
    return cors;
  }

  public Storage getStorage() {
    return storage;
  }

  public Gemini getGemini() {
    return gemini;
  }

  public Groq getGroq() {
    return groq;
  }

  public YouTube getYoutube() {
    return youtube;
  }

  public Access getAccess() {
    return access;
  }

  public Lyrics getLyrics() { return lyrics; }

  public static class Lyrics {
    private final Provider lrclib = new Provider();
    private final Lyricsify lyricsify = new Lyricsify();

    public Provider getLrclib() { return lrclib; }
    public Lyricsify getLyricsify() { return lyricsify; }
  }

  public static class Provider {
    private boolean enabled = true;
    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }
  }

  public static class Lyricsify extends Provider {
    private double minimumConfidence = 0.75;
    private int requestTimeoutSeconds = 10;
    private int retryAfterHours = 12;

    public double getMinimumConfidence() { return minimumConfidence; }
    public void setMinimumConfidence(double value) { minimumConfidence = value; }
    public int getRequestTimeoutSeconds() { return requestTimeoutSeconds; }
    public void setRequestTimeoutSeconds(int value) { requestTimeoutSeconds = value; }
    public int getRetryAfterHours() { return retryAfterHours; }
    public void setRetryAfterHours(int value) { retryAfterHours = value; }
  }

  public static class Cors {
    private List<String> allowedOrigins = new ArrayList<>();

    public List<String> getAllowedOrigins() {
      return allowedOrigins;
    }

    public void setAllowedOrigins(List<String> allowedOrigins) {
      this.allowedOrigins = allowedOrigins;
    }
  }

  public static class Storage {
    private String primary = "disabled";
    private String backup = "disabled";
    private final GoogleDrive googleDrive = new GoogleDrive();
    private final R2 r2 = new R2();

    public String getPrimary() {
      return primary;
    }

    public void setPrimary(String primary) {
      this.primary = primary;
    }

    public String getBackup() {
      return backup;
    }

    public void setBackup(String backup) {
      this.backup = backup;
    }

    public GoogleDrive getGoogleDrive() {
      return googleDrive;
    }

    public R2 getR2() {
      return r2;
    }
  }

  public static class GoogleDrive {
    private boolean enabled;
    private String mode = "oauth";
    private String serviceAccountJson = "";
    private String oauthClientJson = "";
    private String oauthTokenJson = "";
    private String oauthRedirectUri = "http://localhost:8080/api/v1/storage/google-drive/callback";
    private String folderId = "";

    public boolean isEnabled() {
      return enabled;
    }

    public void setEnabled(boolean enabled) {
      this.enabled = enabled;
    }

    public String getMode() {
      return mode;
    }

    public void setMode(String mode) {
      this.mode = mode;
    }

    public String getServiceAccountJson() {
      return serviceAccountJson;
    }

    public void setServiceAccountJson(String serviceAccountJson) {
      this.serviceAccountJson = serviceAccountJson;
    }

    public String getOauthClientJson() {
      return oauthClientJson;
    }

    public void setOauthClientJson(String oauthClientJson) {
      this.oauthClientJson = oauthClientJson;
    }

    public String getOauthTokenJson() {
      return oauthTokenJson;
    }

    public void setOauthTokenJson(String oauthTokenJson) {
      this.oauthTokenJson = oauthTokenJson;
    }

    public String getOauthRedirectUri() {
      return oauthRedirectUri;
    }

    public void setOauthRedirectUri(String oauthRedirectUri) {
      this.oauthRedirectUri = oauthRedirectUri;
    }

    public String getFolderId() {
      return folderId;
    }

    public void setFolderId(String folderId) {
      this.folderId = folderId;
    }
  }

  public static class R2 {
    private boolean enabled;
    private String endpoint = "";
    private String namespace = "";
    private String region = "auto";
    private String accessKeyId = "";
    private String secretAccessKey = "";
    private String bucket = "telugu-tunes-audio";
    private long maxBytes = 8_000_000_000L;

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }
    public String getEndpoint() { return endpoint; }
    public void setEndpoint(String endpoint) { this.endpoint = endpoint; }
    public String getNamespace() { return namespace; }
    public void setNamespace(String namespace) { this.namespace = namespace; }
    public String getRegion() { return region; }
    public void setRegion(String region) { this.region = region; }
    public String getAccessKeyId() { return accessKeyId; }
    public void setAccessKeyId(String accessKeyId) { this.accessKeyId = accessKeyId; }
    public String getSecretAccessKey() { return secretAccessKey; }
    public void setSecretAccessKey(String secretAccessKey) { this.secretAccessKey = secretAccessKey; }
    public String getBucket() { return bucket; }
    public void setBucket(String bucket) { this.bucket = bucket; }
    public long getMaxBytes() { return maxBytes; }
    public void setMaxBytes(long maxBytes) { this.maxBytes = maxBytes; }
  }

  public static class Gemini {
    private String apiKey = "";
    private String model = "gemini-3.7-flash";

    public String getApiKey() {
      return apiKey;
    }

    public void setApiKey(String apiKey) {
      this.apiKey = apiKey;
    }

    public String getModel() {
      return model;
    }

    public void setModel(String model) {
      this.model = model;
    }
  }

  public static class YouTube {
    private String apiKey = "";

    public String getApiKey() {
      return apiKey;
    }

    public void setApiKey(String apiKey) {
      this.apiKey = apiKey;
    }
  }

  public static class Groq {
    private String apiKey = "";
    private String model = "qwen/qwen3-32b";

    public String getApiKey() {
      return apiKey;
    }

    public void setApiKey(String apiKey) {
      this.apiKey = apiKey;
    }

    public String getModel() {
      return model;
    }

    public void setModel(String model) {
      this.model = model;
    }
  }

  public static class Access {
    private String adminEmails = "";

    public String getAdminEmails() {
      return adminEmails;
    }

    public void setAdminEmails(String adminEmails) {
      this.adminEmails = adminEmails;
    }
  }
}
