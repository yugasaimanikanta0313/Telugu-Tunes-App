package com.telugutunes.api.config;

import com.google.api.client.googleapis.javanet.GoogleNetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.google.api.services.drive.Drive;
import com.google.api.services.drive.DriveScopes;
import com.telugutunes.api.service.GoogleDriveOAuthService;
import com.google.auth.http.HttpCredentialsAdapter;
import com.google.auth.oauth2.GoogleCredentials;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.GeneralSecurityException;
import java.util.List;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class GoogleDriveConfiguration {
  @Bean
  @org.springframework.boot.autoconfigure.condition.ConditionalOnExpression(
      "'${app.storage.google-drive.enabled:false}' == 'true' && '${app.storage.google-drive.mode:oauth}' == 'service-account'")
  Drive googleDriveWithServiceAccount(AppProperties properties)
      throws IOException, GeneralSecurityException {
    var drive = properties.getStorage().getGoogleDrive();
    if (drive.getServiceAccountJson().isBlank() || drive.getFolderId().isBlank()) {
      throw new IllegalStateException(
          "Google Drive storage is enabled but its service account file or shared folder ID is missing.");
    }
    try (InputStream credentialsFile = Files.newInputStream(Path.of(drive.getServiceAccountJson()))) {
      var credentials =
          GoogleCredentials.fromStream(credentialsFile).createScoped(List.of(DriveScopes.DRIVE_FILE));
      return new Drive.Builder(
              GoogleNetHttpTransport.newTrustedTransport(),
              GsonFactory.getDefaultInstance(),
              new HttpCredentialsAdapter(credentials))
          .setApplicationName("Telugu Tunes API")
          .build();
    }
  }

  @Bean
  @org.springframework.boot.autoconfigure.condition.ConditionalOnExpression(
      "'${app.storage.google-drive.enabled:false}' == 'true' && '${app.storage.google-drive.mode:oauth}' == 'oauth'")
  Drive googleDriveWithUserOAuth(GoogleDriveOAuthService oauth)
      throws IOException, GeneralSecurityException {
    return new Drive.Builder(
            GoogleNetHttpTransport.newTrustedTransport(), GsonFactory.getDefaultInstance(), oauth)
        .setApplicationName("Telugu Tunes API")
        .build();
  }
}
