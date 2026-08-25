package com.telugutunes.api.config;

import java.net.URI;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;

@Configuration
public class R2Configuration {
  @Bean
  @ConditionalOnProperty(prefix = "app.storage.r2", name = "enabled", havingValue = "true")
  S3Client r2Client(AppProperties properties) {
    var r2 = properties.getStorage().getR2();
    if (r2.getEndpoint().isBlank()
        || r2.getAccessKeyId().isBlank()
        || r2.getSecretAccessKey().isBlank()
        || r2.getBucket().isBlank()) {
      throw new IllegalStateException(
          "R2 is enabled but its endpoint, bucket, or credentials are missing.");
    }
    return S3Client.builder()
        .endpointOverride(URI.create(r2.getEndpoint()))
        .region(Region.of("auto"))
        .credentialsProvider(
            StaticCredentialsProvider.create(
                AwsBasicCredentials.create(r2.getAccessKeyId(), r2.getSecretAccessKey())))
        .serviceConfiguration(S3Configuration.builder().pathStyleAccessEnabled(true).build())
        .build();
  }
}
