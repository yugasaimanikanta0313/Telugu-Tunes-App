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
        && "auto".equalsIgnoreCase(r2.getRegion())) {
      throw new IllegalStateException("S3 storage needs AWS_S3_REGION or R2_ENDPOINT.");
    }
    if (r2.getAccessKeyId().isBlank()
        || r2.getSecretAccessKey().isBlank()
        || r2.getBucket().isBlank()) {
      throw new IllegalStateException(
          "S3 storage is enabled but its bucket or credentials are missing.");
    }
    var builder = S3Client.builder()
        .region(Region.of(r2.getRegion()))
        .credentialsProvider(
            StaticCredentialsProvider.create(
                AwsBasicCredentials.create(r2.getAccessKeyId(), r2.getSecretAccessKey())))
        .serviceConfiguration(
            S3Configuration.builder().pathStyleAccessEnabled(!r2.getEndpoint().isBlank()).build());
    if (!r2.getEndpoint().isBlank()) {
      builder.endpointOverride(URI.create(r2.getEndpoint()));
    }
    return builder.build();
  }
}
