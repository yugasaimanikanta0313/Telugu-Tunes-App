package com.telugutunes.api.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ImportReferenceRequest(
    @NotBlank @Size(max = 40) String source,
    @NotBlank @Size(max = 2_000) String value) {}
