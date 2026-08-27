package com.telugutunes.api.service;

import com.telugutunes.api.config.AppProperties;
import java.io.IOException;
import java.io.OutputStream;
import java.util.UUID;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.ResponseInputStream;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;
import software.amazon.awssdk.services.s3.model.HeadObjectRequest;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Request;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;

@Service
@ConditionalOnBean(S3Client.class)
public class R2StorageService implements MediaStorageService {
  private final S3Client s3;
  private final AppProperties.R2 properties;

  public R2StorageService(S3Client s3, AppProperties properties) {
    this.s3 = s3;
    this.properties = properties.getStorage().getR2();
  }

  @Override
  public String providerName() {
    return properties.getNamespace().isBlank() ? "s3" : "oci";
  }

  @Override
  public StoredMedia upload(MultipartFile source) throws IOException {
    ensureCapacity(source.getSize());
    var fileName = safeFileName(source.getOriginalFilename());
    var contentType = source.getContentType() == null ? "audio/mpeg" : source.getContentType();
    var key = "audio/" + UUID.randomUUID() + "-" + fileName;
    try (var input = source.getInputStream()) {
      s3.putObject(
          PutObjectRequest.builder()
              .bucket(properties.getBucket())
              .key(key)
              .contentType(contentType)
              .build(),
          RequestBody.fromInputStream(input, source.getSize()));
      return new StoredMedia(key, fileName, contentType, source.getSize(), source.getSize(), false);
    } catch (S3Exception exception) {
      throw storageFailure("upload", exception);
    }
  }

  @Override
  public StoredMediaInfo mediaInfo(String objectId) throws IOException {
    try {
      var response =
          s3.headObject(
              HeadObjectRequest.builder().bucket(properties.getBucket()).key(objectId).build());
      return new StoredMediaInfo(
          response.contentLength(),
          response.contentType() == null ? "audio/mpeg" : response.contentType());
    } catch (S3Exception exception) {
      throw storageFailure("read metadata", exception);
    }
  }

  @Override
  public void stream(String objectId, long start, long end, OutputStream target)
      throws IOException {
    try (ResponseInputStream<GetObjectResponse> input =
        s3.getObject(
            GetObjectRequest.builder()
                .bucket(properties.getBucket())
                .key(objectId)
                .range("bytes=" + start + "-" + end)
                .build())) {
      input.transferTo(target);
    } catch (S3Exception exception) {
      throw storageFailure("stream", exception);
    }
  }

  @Override
  public void delete(String objectId) throws IOException {
    if (objectId == null || objectId.isBlank()) return;
    try {
      s3.deleteObject(
          DeleteObjectRequest.builder().bucket(properties.getBucket()).key(objectId).build());
    } catch (S3Exception exception) {
      throw storageFailure("delete", exception);
    }
  }

  private void ensureCapacity(long incomingBytes) throws IOException {
    long usedBytes = 0;
    try {
      var pages =
          s3.listObjectsV2Paginator(
              ListObjectsV2Request.builder().bucket(properties.getBucket()).prefix("audio/").build());
      for (var page : pages) {
        for (var object : page.contents()) usedBytes += object.size();
      }
    } catch (S3Exception exception) {
      throw storageFailure("check capacity", exception);
    }
    if (usedBytes + incomingBytes > properties.getMaxBytes()) {
      throw new IOException(
          "The private music library has reached its configured storage safety limit.");
    }
  }

  private IOException storageFailure(String action, S3Exception exception) {
    return new IOException("S3 storage could not " + action + " this audio file.", exception);
  }

  private String safeFileName(String fileName) {
    var candidate = fileName == null || fileName.isBlank() ? "uploaded-track.mp3" : fileName;
    return candidate.replaceAll("[^a-zA-Z0-9._ -]", "_");
  }
}
