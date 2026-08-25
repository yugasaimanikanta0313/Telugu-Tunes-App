package com.telugutunes.api.domain;

import java.time.Instant;
import java.util.Set;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("members")
public record Member(
    @Id String id,
    String displayName,
    String email,
    String passwordHash,
    Set<MemberRole> roles,
    boolean active,
    Instant createdAt) {}
