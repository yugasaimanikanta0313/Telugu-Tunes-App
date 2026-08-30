package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.ResetPasswordRequest;
import com.telugutunes.api.api.dto.VerifyResetOtpRequest;
import com.telugutunes.api.domain.Member;
import com.telugutunes.api.domain.PasswordResetDocument;
import com.telugutunes.api.repository.AuthSessionRepository;
import com.telugutunes.api.repository.MemberRepository;
import com.telugutunes.api.repository.PasswordResetRepository;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import org.springframework.stereotype.Service;

@Service
public class PasswordResetService {
  private final MemberRepository members;
  private final PasswordResetRepository resets;
  private final AuthSessionRepository sessions;
  private final PasswordService passwords;
  private final PasswordResetMailService mail;
  private final SecureRandom random = new SecureRandom();

  public PasswordResetService(
      MemberRepository members,
      PasswordResetRepository resets,
      AuthSessionRepository sessions,
      PasswordService passwords,
      PasswordResetMailService mail) {
    this.members = members;
    this.resets = resets;
    this.sessions = sessions;
    this.passwords = passwords;
    this.mail = mail;
  }

  public void request(String rawEmail) {
    var email = rawEmail.trim().toLowerCase();
    var member = members.findByEmailIgnoreCase(email).filter(Member::active).orElse(null);
    if (member == null) return;
    var existing = resets.findById(email).orElse(null);
    var now = Instant.now();
    if (existing != null && existing.requestedAt().plus(60, ChronoUnit.SECONDS).isAfter(now)) {
      return;
    }
    var otp = "%06d".formatted(random.nextInt(1_000_000));
    resets.save(new PasswordResetDocument(
        email, member.id(), hash(email + ":" + otp), "", 0,
        now.plus(10, ChronoUnit.MINUTES), null, now));
    try {
      mail.sendOtp(email, otp);
    } catch (RuntimeException exception) {
      resets.deleteById(email);
      throw exception;
    }
  }

  public String verify(VerifyResetOtpRequest request) {
    var email = request.email().trim().toLowerCase();
    var reset = resets.findById(email)
        .orElseThrow(() -> new IllegalArgumentException("The verification code is invalid or expired."));
    var now = Instant.now();
    if (reset.otpExpiresAt().isBefore(now) || reset.failedAttempts() >= 5) {
      resets.delete(reset);
      throw new IllegalArgumentException("The verification code is invalid or expired.");
    }
    if (!constantTimeEquals(reset.otpHash(), hash(email + ":" + request.otp()))) {
      resets.save(new PasswordResetDocument(
          reset.email(), reset.memberId(), reset.otpHash(), "", reset.failedAttempts() + 1,
          reset.otpExpiresAt(), null, reset.requestedAt()));
      throw new IllegalArgumentException("The verification code is invalid or expired.");
    }
    var tokenBytes = new byte[32];
    random.nextBytes(tokenBytes);
    var token = Base64.getUrlEncoder().withoutPadding().encodeToString(tokenBytes);
    resets.save(new PasswordResetDocument(
        reset.email(), reset.memberId(), "", hash(token), reset.failedAttempts(),
        reset.otpExpiresAt(), now.plus(10, ChronoUnit.MINUTES), reset.requestedAt()));
    return token;
  }

  public void reset(ResetPasswordRequest request) {
    var email = request.email().trim().toLowerCase();
    var reset = resets.findById(email)
        .orElseThrow(() -> new IllegalArgumentException("The password reset session is invalid or expired."));
    var now = Instant.now();
    if (reset.resetTokenExpiresAt() == null || reset.resetTokenExpiresAt().isBefore(now)
        || !constantTimeEquals(reset.resetTokenHash(), hash(request.resetToken()))) {
      throw new IllegalArgumentException("The password reset session is invalid or expired.");
    }
    var member = members.findById(reset.memberId())
        .orElseThrow(() -> new IllegalArgumentException("The password reset session is invalid or expired."));
    members.save(new Member(member.id(), member.displayName(), member.email(),
        passwords.hash(request.newPassword()), member.roles(), member.active(), member.createdAt()));
    sessions.deleteByMemberId(member.id());
    resets.delete(reset);
  }

  private String hash(String value) {
    try {
      return Base64.getUrlEncoder().withoutPadding().encodeToString(
          MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
    } catch (Exception exception) {
      throw new IllegalStateException("Password reset protection is unavailable.", exception);
    }
  }

  private boolean constantTimeEquals(String left, String right) {
    return MessageDigest.isEqual(left.getBytes(StandardCharsets.UTF_8), right.getBytes(StandardCharsets.UTF_8));
  }
}
