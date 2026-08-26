package com.telugutunes.api.api.dto;

import com.telugutunes.api.domain.ImportJob;
import com.telugutunes.api.service.MediaStorageService;

public record ImportResponse(
    String id,
    String status,
    String message,
    String originalFileName,
    long originalBytes,
    long storedBytes,
    boolean compressed) {
  public static ImportResponse from(ImportJob job) {
    return new ImportResponse(
        job.id(), job.status().name(), job.message(), job.originalFileName(), 0, 0, false);
  }

  public static ImportResponse from(ImportJob job, MediaStorageService.StoredMedia media) {
    return new ImportResponse(
        job.id(),
        job.status().name(),
        job.message(),
        job.originalFileName(),
        media.originalBytes(),
        media.storedBytes(),
        media.compressed());
  }
}
