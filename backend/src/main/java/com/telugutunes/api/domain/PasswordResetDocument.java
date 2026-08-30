package com.telugutunes.api.domain;

import java.time.Instant;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("password_resets")
public record PasswordResetDocument(
    @Id String email,
    String memberId,
    String otpHash,
    String resetTokenHash,
    int failedAttempts,
    Instant otpExpiresAt,
    Instant resetTokenExpiresAt,
    Instant requestedAt) {}
