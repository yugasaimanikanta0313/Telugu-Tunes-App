package com.telugutunes.api.service;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Locale;
import java.util.concurrent.TimeUnit;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

/** Transcodes oversized uploads to browser-safe MP3 and guarantees storage below 5 MB. */
@Service
public class AudioCompressionService {
  public static final long MAX_STORED_BYTES = 5_000_000L;
  private static final long TARGET_BYTES = 4_850_000L;
  private static final long MIN_BITRATE = 16_000L;
  private static final long MAX_BITRATE = 192_000L;

  public PreparedAudio prepare(MultipartFile source) throws IOException {
    if (source.getSize() <= MAX_STORED_BYTES) {
      return new PreparedAudio(source, source.getSize(), source.getSize(), false, null);
    }

    var input = Files.createTempFile("telugu-tunes-input-", suffix(source.getOriginalFilename()));
    Path output = null;
    try {
      source.transferTo(input);
      var durationSeconds = probeDuration(input);
      var bitrate = initialBitrate(durationSeconds);
      for (var attempt = 0; attempt < 5; attempt++) {
        output = Files.createTempFile("telugu-tunes-compressed-", ".mp3");
        transcode(input, output, bitrate);
        var storedBytes = Files.size(output);
        if (storedBytes > 0 && storedBytes <= MAX_STORED_BYTES) {
          var preparedFile =
              new PathMultipartFile(
                  "file", compressedName(source.getOriginalFilename()), "audio/mpeg", output);
          output = null;
          return new PreparedAudio(
              preparedFile, source.getSize(), storedBytes, true, preparedFile.path());
        }
        Files.deleteIfExists(output);
        output = null;
        var ratio = storedBytes <= 0 ? 0.75 : (double) TARGET_BYTES / storedBytes;
        bitrate = Math.max(MIN_BITRATE, (long) (bitrate * Math.min(0.85, ratio * 0.92)));
      }
      throw new IOException("This audio could not be compressed below the 5 MB storage limit.");
    } finally {
      Files.deleteIfExists(input);
      if (output != null) Files.deleteIfExists(output);
    }
  }

  private double probeDuration(Path input) throws IOException {
    var process =
        new ProcessBuilder(
                "ffprobe",
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                input.toString())
            .redirectErrorStream(true)
            .start();
    try {
      if (!process.waitFor(30, TimeUnit.SECONDS)) {
        process.destroyForcibly();
        throw new IOException("Audio inspection timed out.");
      }
      var value = new String(process.getInputStream().readAllBytes()).trim();
      if (process.exitValue() != 0) throw new IOException("The selected file is not readable audio.");
      return Double.parseDouble(value);
    } catch (InterruptedException exception) {
      Thread.currentThread().interrupt();
      throw new IOException("Audio inspection was interrupted.", exception);
    } catch (NumberFormatException exception) {
      throw new IOException("The selected audio duration could not be detected.", exception);
    }
  }

  private void transcode(Path input, Path output, long bitrate) throws IOException {
    var process =
        new ProcessBuilder(
                "ffmpeg",
                "-y",
                "-v",
                "error",
                "-i",
                input.toString(),
                "-vn",
                "-map_metadata",
                "-1",
                "-c:a",
                "libmp3lame",
                "-b:a",
                Long.toString(bitrate),
                "-id3v2_version",
                "3",
                output.toString())
            .redirectErrorStream(true)
            .start();
    try {
      if (!process.waitFor(120, TimeUnit.SECONDS)) {
        process.destroyForcibly();
        throw new IOException("Audio compression timed out.");
      }
      var outputText = new String(process.getInputStream().readAllBytes()).trim();
      if (process.exitValue() != 0) {
        throw new IOException(
            outputText.isBlank() ? "FFmpeg could not compress this audio." : outputText);
      }
    } catch (InterruptedException exception) {
      Thread.currentThread().interrupt();
      throw new IOException("Audio compression was interrupted.", exception);
    }
  }

  private long initialBitrate(double durationSeconds) throws IOException {
    if (!Double.isFinite(durationSeconds) || durationSeconds <= 0) {
      throw new IOException("The selected audio has an invalid duration.");
    }
    var availableBitsPerSecond = (long) ((TARGET_BYTES * 8.0) / durationSeconds);
    if (availableBitsPerSecond < MIN_BITRATE) {
      throw new IOException("This audio is too long to fit safely below 5 MB.");
    }
    return Math.min(MAX_BITRATE, availableBitsPerSecond);
  }

  private String compressedName(String originalName) {
    var candidate = originalName == null || originalName.isBlank() ? "uploaded-track" : originalName;
    var dot = candidate.lastIndexOf('.');
    var base = dot > 0 ? candidate.substring(0, dot) : candidate;
    return base + ".mp3";
  }

  private String suffix(String fileName) {
    if (fileName == null) return ".audio";
    var dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length() - 1) return ".audio";
    var value = fileName.substring(dot).toLowerCase(Locale.ROOT);
    return value.matches("\\.[a-z0-9]{1,8}") ? value : ".audio";
  }

  public record PreparedAudio(
      MultipartFile file,
      long originalBytes,
      long storedBytes,
      boolean compressed,
      Path temporaryPath)
      implements AutoCloseable {
    @Override
    public void close() throws IOException {
      if (temporaryPath != null) Files.deleteIfExists(temporaryPath);
    }
  }

  private static final class PathMultipartFile implements MultipartFile {
    private final String name;
    private final String originalFilename;
    private final String contentType;
    private final Path path;

    private PathMultipartFile(String name, String originalFilename, String contentType, Path path) {
      this.name = name;
      this.originalFilename = originalFilename;
      this.contentType = contentType;
      this.path = path;
    }

    private Path path() {
      return path;
    }

    @Override
    public String getName() {
      return name;
    }

    @Override
    public String getOriginalFilename() {
      return originalFilename;
    }

    @Override
    public String getContentType() {
      return contentType;
    }

    @Override
    public boolean isEmpty() {
      try {
        return Files.size(path) == 0;
      } catch (IOException exception) {
        return true;
      }
    }

    @Override
    public long getSize() {
      try {
        return Files.size(path);
      } catch (IOException exception) {
        return 0;
      }
    }

    @Override
    public byte[] getBytes() throws IOException {
      return Files.readAllBytes(path);
    }

    @Override
    public InputStream getInputStream() throws IOException {
      return Files.newInputStream(path);
    }

    @Override
    public void transferTo(File destination) throws IOException {
      Files.copy(path, destination.toPath(), StandardCopyOption.REPLACE_EXISTING);
    }
  }
}
