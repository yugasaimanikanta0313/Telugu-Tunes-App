package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.AuthResponse;
import com.telugutunes.api.api.dto.MemberProfileResponse;
import com.telugutunes.api.api.dto.LoginRequest;
import com.telugutunes.api.api.dto.RegisterRequest;
import com.telugutunes.api.domain.AuthSessionDocument;
import com.telugutunes.api.domain.Member;
import com.telugutunes.api.domain.MemberRole;
import com.telugutunes.api.exception.NotFoundException;
import com.telugutunes.api.repository.AuthSessionRepository;
import com.telugutunes.api.repository.MemberRepository;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.HashSet;
import java.util.Set;
import org.springframework.stereotype.Service;

@Service
public class AuthService {
  private final MemberRepository members;
  private final AuthSessionRepository sessions;
  private final PasswordService passwords;
  private final com.telugutunes.api.config.AppProperties properties;
  private final SecureRandom random = new SecureRandom();

  public AuthService(
      MemberRepository members,
      AuthSessionRepository sessions,
      PasswordService passwords,
      com.telugutunes.api.config.AppProperties properties) {
    this.members = members;
    this.sessions = sessions;
    this.passwords = passwords;
    this.properties = properties;
  }

  public AuthResponse register(RegisterRequest request) {
    var email = request.email().trim().toLowerCase();
    if (members.findByEmailIgnoreCase(email).isPresent()) {
      throw new IllegalStateException("An account with that email already exists.");
    }
    // Earlier development builds created anonymous members without passwords.
    // The first account-capable member remains the owner when that legacy data exists.
    var roles = new HashSet<MemberRole>();
    roles.add(members.countByPasswordHashIsNotNull() == 0 ? MemberRole.OWNER : MemberRole.MEMBER);
    if (isConfiguredAdministrator(email)) roles.add(MemberRole.ADMIN);
    var member =
        members.save(
            new Member(
                null,
                request.displayName().trim(),
                email,
                passwords.hash(request.password()),
                Set.copyOf(roles),
                true,
                Instant.now()));
    return sessionFor(ensureConfiguredAdministrator(member));
  }

  public AuthResponse login(LoginRequest request) {
    var member =
        members
            .findByEmailIgnoreCase(request.email().trim())
            .filter(Member::active)
            .orElseThrow(() -> new IllegalArgumentException("Email or password is incorrect."));
    if (!passwords.matches(request.password(), member.passwordHash())) {
      throw new IllegalArgumentException("Email or password is incorrect.");
    }
    return sessionFor(ensureConfiguredAdministrator(member));
  }

  public Member memberForToken(String rawToken) {
    if (rawToken == null || rawToken.isBlank()) throw new IllegalArgumentException("Sign in is required.");
    var session =
        sessions
            .findByTokenHash(tokenHash(rawToken))
            .filter(value -> value.expiresAt().isAfter(Instant.now()))
            .orElseThrow(() -> new IllegalArgumentException("Your sign-in session has expired."));
    var member =
        members
            .findById(session.memberId())
            .filter(Member::active)
            .orElseThrow(() -> new NotFoundException("Member not found."));
    return ensureConfiguredAdministrator(member);
  }

  public void signOut(String rawToken) {
    sessions.findByTokenHash(tokenHash(rawToken)).ifPresent(sessions::delete);
  }

  public MemberProfileResponse profile(String memberId) {
    var member =
        members.findById(memberId).orElseThrow(() -> new NotFoundException("Member not found."));
    return MemberProfileResponse.from(ensureConfiguredAdministrator(member));
  }

  public void requireAdministrator(String memberId) {
    var member =
        members.findById(memberId).orElseThrow(() -> new NotFoundException("Member not found."));
    if (!isAdministrator(member)) {
      throw new IllegalArgumentException("Administrator access is required.");
    }
  }

  public boolean isAdministrator(Member member) {
    return member.roles().contains(MemberRole.OWNER) || member.roles().contains(MemberRole.ADMIN);
  }

  private Member ensureConfiguredAdministrator(Member member) {
    if (!isConfiguredAdministrator(member.email()) || isAdministrator(member)) return member;
    var roles = new HashSet<>(member.roles());
    roles.add(MemberRole.ADMIN);
    return members.save(
        new Member(
            member.id(),
            member.displayName(),
            member.email(),
            member.passwordHash(),
            Set.copyOf(roles),
            member.active(),
            member.createdAt()));
  }

  private boolean isConfiguredAdministrator(String email) {
    var configured = properties.getAccess().getAdminEmails();
    if (configured == null || configured.isBlank()) return false;
    return java.util.Arrays.stream(configured.split(","))
        .map(String::trim)
        .filter(value -> !value.isBlank())
        .anyMatch(value -> value.equalsIgnoreCase(email));
  }

  private AuthResponse sessionFor(Member member) {
    var bytes = new byte[32];
    random.nextBytes(bytes);
    var token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    var now = Instant.now();
    sessions.save(new AuthSessionDocument(null, tokenHash(token), member.id(), now.plus(30, ChronoUnit.DAYS), now));
    return new AuthResponse(token, member.id(), member.displayName(), member.email(), isAdministrator(member));
  }

  private String tokenHash(String token) {
    try {
      return Base64.getUrlEncoder().withoutPadding().encodeToString(
          MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8)));
    } catch (Exception exception) {
      throw new IllegalStateException("Session protection is unavailable.", exception);
    }
  }
}
