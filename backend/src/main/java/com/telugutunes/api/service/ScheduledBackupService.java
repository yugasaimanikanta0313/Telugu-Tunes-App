package com.telugutunes.api.service;

import tools.jackson.databind.ObjectMapper;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.Comparator;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

@Service
public class ScheduledBackupService {
  private static final DateTimeFormatter FILE_TIME =
      DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss").withZone(ZoneOffset.UTC);
  private final BackupService backups;
  private final ObjectMapper json;
  private final Path directory;
  private final boolean enabled;
  private final int retention;

  public ScheduledBackupService(
      BackupService backups,
      ObjectMapper json,
      @Value("${app.backups.directory:/app/backups}") String directory,
      @Value("${app.backups.enabled:true}") boolean enabled,
      @Value("${app.backups.retention:30}") int retention) {
    this.backups = backups;
    this.json = json;
    this.directory = Path.of(directory).toAbsolutePath().normalize();
    this.enabled = enabled;
    this.retention = Math.max(3, retention);
  }

  @Scheduled(cron = "${app.backups.cron:0 15 2 * * *}", zone = "UTC")
  public void createVersionedBackup() throws Exception {
    if (!enabled) return;
    Files.createDirectories(directory);
    var target = directory.resolve("telugu-tunes-" + FILE_TIME.format(Instant.now()) + ".json");
    json.writerWithDefaultPrettyPrinter().writeValue(target.toFile(), backups.exportSystemSnapshot());
    try (var files = Files.list(directory)) {
      var old = files
          .filter(path -> path.getFileName().toString().startsWith("telugu-tunes-"))
          .filter(path -> path.getFileName().toString().endsWith(".json"))
          .sorted(Comparator.comparingLong(this::modified).reversed())
          .skip(retention)
          .toList();
      for (var path : old) Files.deleteIfExists(path);
    }
  }

  private long modified(Path path) {
    try {
      return Files.getLastModifiedTime(path).toMillis();
    } catch (Exception ignored) {
      return 0;
    }
  }
}
