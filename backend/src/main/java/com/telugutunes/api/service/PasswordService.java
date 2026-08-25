package com.telugutunes.api.service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.security.spec.KeySpec;
import java.util.Base64;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import org.springframework.stereotype.Service;

/** PBKDF2 hashes passwords; raw passwords never enter MongoDB. */
@Service
public class PasswordService {
  private static final int ITERATIONS = 210_000;
  private static final int KEY_LENGTH = 256;
  private final SecureRandom random = new SecureRandom();

  public String hash(String password) {
    var salt = new byte[16];
    random.nextBytes(salt);
    return Base64.getEncoder().encodeToString(salt) + ":" + Base64.getEncoder().encodeToString(derive(password, salt));
  }

  public boolean matches(String password, String encoded) {
    if (encoded == null || !encoded.contains(":")) return false;
    var parts = encoded.split(":", 2);
    try {
      var salt = Base64.getDecoder().decode(parts[0]);
      var expected = Base64.getDecoder().decode(parts[1]);
      return MessageDigest.isEqual(expected, derive(password, salt));
    } catch (IllegalArgumentException exception) {
      return false;
    }
  }

  private byte[] derive(String password, byte[] salt) {
    try {
      KeySpec spec = new PBEKeySpec(password.toCharArray(), salt, ITERATIONS, KEY_LENGTH);
      return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded();
    } catch (Exception exception) {
      throw new IllegalStateException("Password protection is unavailable.", exception);
    }
  }
}
