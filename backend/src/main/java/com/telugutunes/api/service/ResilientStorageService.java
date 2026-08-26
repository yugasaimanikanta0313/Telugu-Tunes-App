package com.telugutunes.api.service;

import com.telugutunes.api.config.AppProperties;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
public class ResilientStorageService {
  private static final Logger log = LoggerFactory.getLogger(ResilientStorageService.class);
  private static final String LOCATOR_PREFIX = "tt1";

  private final Map<String, MediaStorageService> providers;
  private final AppProperties.Storage properties;

  public ResilientStorageService(List<MediaStorageService> providers, AppProperties properties) {
    this.providers = new LinkedHashMap<>();
    providers.forEach(provider -> this.providers.put(provider.providerName(), provider));
    if (this.providers.containsKey("s3")) {
      this.providers.put("r2", this.providers.get("s3"));
    }
    this.properties = properties.getStorage();
  }

  public boolean isConfigured() {
    return providers.containsKey(properties.getPrimary());
  }

  public MediaStorageService.StoredMedia upload(MultipartFile source) throws IOException {
    var primary = provider(properties.getPrimary());
    MediaStorageService.StoredMedia primaryMedia;
    try {
      primaryMedia = primary.upload(source);
    } catch (IOException primaryFailure) {
      var backup = optionalProvider(properties.getBackup());
      if (backup == null) throw primaryFailure;
      log.warn("Primary storage upload failed; recovery provider is active.");
      var backupMedia = backup.upload(source);
      return withLocator(List.of(new Replica(backup.providerName(), backupMedia.objectId())), backupMedia);
    }

    var replicas = new ArrayList<Replica>();
    replicas.add(new Replica(primary.providerName(), primaryMedia.objectId()));
    var backup = optionalProvider(properties.getBackup());
    if (backup != null && backup != primary) {
      try {
        var backupMedia = backup.upload(source);
        replicas.add(new Replica(backup.providerName(), backupMedia.objectId()));
      } catch (IOException backupFailure) {
        log.warn("Backup storage replication is pending: {}", backupFailure.getMessage());
      }
    }
    return withLocator(replicas, primaryMedia);
  }

  public MediaStorageService.StoredMediaInfo mediaInfo(String locator) throws IOException {
    IOException lastFailure = null;
    for (var replica : replicas(locator)) {
      var provider = optionalProvider(replica.provider());
      if (provider == null) continue;
      try {
        return provider.mediaInfo(replica.objectId());
      } catch (IOException failure) {
        lastFailure = failure;
      }
    }
    throw lastFailure == null
        ? new IOException("No configured storage provider can read this track.")
        : lastFailure;
  }

  public void stream(String locator, long start, long end, OutputStream target) throws IOException {
    IOException lastFailure = null;
    for (var replica : replicas(locator)) {
      var provider = optionalProvider(replica.provider());
      if (provider == null) continue;
      try {
        provider.stream(replica.objectId(), start, end, target);
        return;
      } catch (IOException failure) {
        lastFailure = failure;
        log.warn("Storage read failed on {}; trying the next replica.", replica.provider());
      }
    }
    throw lastFailure == null
        ? new IOException("No configured storage provider can stream this track.")
        : lastFailure;
  }

  public void delete(String locator) throws IOException {
    IOException lastFailure = null;
    for (var replica : replicas(locator)) {
      var provider = optionalProvider(replica.provider());
      if (provider == null) continue;
      try {
        provider.delete(replica.objectId());
      } catch (IOException failure) {
        lastFailure = failure;
      }
    }
    if (lastFailure != null) throw lastFailure;
  }

  private MediaStorageService.StoredMedia withLocator(
      List<Replica> replicas, MediaStorageService.StoredMedia media) {
    return new MediaStorageService.StoredMedia(
        encode(replicas), media.fileName(), media.mimeType());
  }

  private MediaStorageService provider(String name) throws IOException {
    var provider = optionalProvider(name);
    if (provider == null) throw new IOException("Private audio storage is not configured.");
    return provider;
  }

  private MediaStorageService optionalProvider(String name) {
    return name == null || name.isBlank() || "disabled".equals(name) ? null : providers.get(name);
  }

  private String encode(List<Replica> replicas) {
    var encoder = Base64.getUrlEncoder().withoutPadding();
    var parts = new ArrayList<String>();
    parts.add(LOCATOR_PREFIX);
    for (var replica : replicas) {
      parts.add(replica.provider());
      parts.add(encoder.encodeToString(replica.objectId().getBytes(StandardCharsets.UTF_8)));
    }
    return String.join("|", parts);
  }

  private List<Replica> replicas(String locator) {
    if (locator == null || locator.isBlank()) return List.of();
    if (!locator.startsWith(LOCATOR_PREFIX + "|")) {
      return List.of(new Replica("google-drive", locator));
    }
    var parts = locator.split("\\|");
    var decoder = Base64.getUrlDecoder();
    var replicas = new ArrayList<Replica>();
    for (var index = 1; index + 1 < parts.length; index += 2) {
      try {
        replicas.add(
            new Replica(
                parts[index],
                new String(decoder.decode(parts[index + 1]), StandardCharsets.UTF_8)));
      } catch (IllegalArgumentException ignored) {
        // Ignore a malformed replica and continue with any valid copy.
      }
    }
    return replicas;
  }

  private record Replica(String provider, String objectId) {}
}
