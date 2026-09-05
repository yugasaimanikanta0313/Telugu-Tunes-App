package com.telugutunes.api.service;

import com.telugutunes.api.domain.TrackFingerprintDocument;
import com.telugutunes.api.repository.TrackFingerprintRepository;
import com.telugutunes.api.repository.TrackRepository;
import java.nio.file.Files;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.List;
import java.util.concurrent.TimeUnit;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
public class AudioFingerprintService {
  private final TrackFingerprintRepository fingerprints;
  private final TrackRepository tracks;

  public AudioFingerprintService(
      TrackFingerprintRepository fingerprints, TrackRepository tracks) {
    this.fingerprints = fingerprints;
    this.tracks = tracks;
  }

  public Analysis analyze(MultipartFile file) throws java.io.IOException {
    var bytes = file.getBytes();
    var exact = sha256(bytes);
    var acoustic = List.<Integer>of();
    var duration = 0;
    var temporary = Files.createTempFile("telugu-tunes-fingerprint-", ".audio");
    try {
      Files.write(temporary, bytes);
      var process = new ProcessBuilder("fpcalc", "-raw", "-length", "180", temporary.toString())
          .redirectErrorStream(true)
          .start();
      if (process.waitFor(25, TimeUnit.SECONDS) && process.exitValue() == 0) {
        for (var line : new String(process.getInputStream().readAllBytes()).split("\\R")) {
          if (line.startsWith("DURATION=")) {
            duration = (int) Math.round(Double.parseDouble(line.substring(9).trim()));
          } else if (line.startsWith("FINGERPRINT=")) {
            var values = new ArrayList<Integer>();
            for (var value : line.substring(12).split(",")) {
              if (!value.isBlank()) values.add(Integer.parseInt(value.trim()));
            }
            acoustic = List.copyOf(values);
          }
        }
      } else if (process.isAlive()) {
        process.destroyForcibly();
      }
    } catch (Exception ignored) {
      // Exact byte hashing remains available when fpcalc is not installed locally.
    } finally {
      Files.deleteIfExists(temporary);
    }
    return new Analysis(exact, acoustic, duration);
  }

  public void rejectDuplicate(Analysis candidate) {
    var exact = fingerprints.findByFileSha256(candidate.fileSha256()).orElse(null);
    if (isLive(exact)) {
      throw new IllegalArgumentException("This exact audio file already exists in the catalog.");
    }
    if (candidate.acousticFingerprint().isEmpty()) return;
    for (var existing : fingerprints.findAll()) {
      if (!isLive(existing) || existing.acousticFingerprint() == null
          || existing.acousticFingerprint().isEmpty()) continue;
      if (Math.abs(existing.durationSeconds() - candidate.durationSeconds()) > 3) continue;
      if (similarity(existing.acousticFingerprint(), candidate.acousticFingerprint()) >= .92) {
        throw new IllegalArgumentException(
            "This audio sounds the same as a song already in the catalog.");
      }
    }
  }

  public void save(String trackId, Analysis analysis) {
    fingerprints.save(new TrackFingerprintDocument(
        null, trackId, analysis.fileSha256(), analysis.acousticFingerprint(),
        analysis.durationSeconds(), Instant.now()));
  }

  private boolean isLive(TrackFingerprintDocument value) {
    if (value == null) return false;
    if (tracks.existsById(value.trackId())) return true;
    fingerprints.delete(value);
    return false;
  }

  private double similarity(List<Integer> left, List<Integer> right) {
    var size = Math.min(left.size(), right.size());
    if (size < 8) return 0;
    long differentBits = 0;
    for (var index = 0; index < size; index++) {
      differentBits += Integer.bitCount(left.get(index) ^ right.get(index));
    }
    return 1d - ((double) differentBits / (size * 32d));
  }

  private String sha256(byte[] bytes) {
    try {
      return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
    } catch (Exception exception) {
      throw new IllegalStateException("SHA-256 is unavailable.", exception);
    }
  }

  public record Analysis(String fileSha256, List<Integer> acousticFingerprint, int durationSeconds) {}
}
