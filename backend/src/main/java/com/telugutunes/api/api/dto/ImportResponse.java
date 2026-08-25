package com.telugutunes.api.api.dto;

import com.telugutunes.api.domain.ImportJob;

public record ImportResponse(String id, String status, String message, String originalFileName) {
  public static ImportResponse from(ImportJob job) {
    return new ImportResponse(job.id(), job.status().name(), job.message(), job.originalFileName());
  }
}
