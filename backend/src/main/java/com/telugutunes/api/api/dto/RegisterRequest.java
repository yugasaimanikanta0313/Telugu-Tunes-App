package com.telugutunes.api.api.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record RegisterRequest(
    @NotBlank @Size(max = 80) String displayName,
    @NotBlank @Email String email,
    @NotBlank @Size(min = 8, max = 200) String password) {}
