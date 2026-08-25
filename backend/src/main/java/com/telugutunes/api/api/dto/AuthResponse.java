package com.telugutunes.api.api.dto;

public record AuthResponse(
    String token, String memberId, String displayName, String email, boolean admin) {}
