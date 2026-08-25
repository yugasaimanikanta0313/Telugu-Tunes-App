package com.telugutunes.api.api;

import com.telugutunes.api.service.GoogleDriveOAuthService;
import java.io.IOException;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.view.RedirectView;

@RestController
@RequestMapping("/api/v1/storage/google-drive")
public class GoogleDriveOAuthController {
  private final ObjectProvider<GoogleDriveOAuthService> oauth;

  public GoogleDriveOAuthController(ObjectProvider<GoogleDriveOAuthService> oauth) {
    this.oauth = oauth;
  }

  @GetMapping("/connect")
  public RedirectView connect() throws IOException {
    return new RedirectView(service().authorizationUrl());
  }

  @GetMapping("/callback")
  public ResponseEntity<String> callback(
      @RequestParam(required = false) String code, @RequestParam(required = false) String state) {
    if (code == null || state == null) {
      return page(400, "Google Drive connection was cancelled. You can close this tab and try again.");
    }
    try {
      service().completeAuthorization(code, state);
      return page(200, "Google Drive is connected. You can close this tab and return to Telugu Tunes.");
    } catch (InterruptedException exception) {
      Thread.currentThread().interrupt();
      return page(400, "Google Drive could not be connected. Return to the app and try again.");
    } catch (IOException | IllegalArgumentException exception) {
      return page(400, "Google Drive could not be connected. Return to the app and try again.");
    }
  }

  @GetMapping("/status")
  public DriveConnectionStatus status() {
    var configured = oauth.getIfAvailable();
    return new DriveConnectionStatus(configured != null, configured != null && configured.isConnected());
  }

  private GoogleDriveOAuthService service() {
    var configured = oauth.getIfAvailable();
    if (configured == null) {
      throw new ResponseStatusException(
          HttpStatus.SERVICE_UNAVAILABLE,
          "Google Drive OAuth is not configured. Check app.storage.provider in secrets.yml.");
    }
    return configured;
  }

  private ResponseEntity<String> page(int status, String message) {
    var html =
        "<!doctype html><html><head><meta charset=\"utf-8\"><title>Telugu Tunes</title>"
            + "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"></head>"
            + "<body style=\"font-family:system-ui;padding:2rem;max-width:42rem\"><h1>Telugu Tunes</h1><p>"
            + message
            + "</p></body></html>";
    return ResponseEntity.status(status).contentType(MediaType.TEXT_HTML).body(html);
  }

  public record DriveConnectionStatus(boolean configured, boolean connected) {}
}
