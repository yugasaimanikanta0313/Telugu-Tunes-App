package com.telugutunes.api.domain;

import java.time.Instant;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("import_jobs")
public record ImportJob(
    @Id String id,
    String requestedByMemberId,
    String source,
    String originalFileName,
    String driveFileId,
    ImportStatus status,
    String message,
    Instant createdAt,
    Instant updatedAt) {}
