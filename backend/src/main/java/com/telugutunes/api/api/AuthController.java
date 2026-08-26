package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.AuthResponse;
import com.telugutunes.api.api.dto.LoginRequest;
import com.telugutunes.api.api.dto.RegisterRequest;
import com.telugutunes.api.service.AuthService;
import jakarta.validation.Valid;
import jakarta.servlet.http.HttpServletResponse;
import java.time.Duration;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseCookie;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
  private final AuthService auth;

  public AuthController(AuthService auth) {
    this.auth = auth;
  }

  @PostMapping("/register")
  @ResponseStatus(HttpStatus.CREATED)
  public AuthResponse register(
      @Valid @RequestBody RegisterRequest request, HttpServletResponse response) {
    var session = auth.register(request);
    setBrowserSessionCookie(response, session.token());
    return session;
  }

  @PostMapping("/login")
  public AuthResponse login(@Valid @RequestBody LoginRequest request, HttpServletResponse response) {
    var session = auth.login(request);
    setBrowserSessionCookie(response, session.token());
    return session;
  }

  private void setBrowserSessionCookie(HttpServletResponse response, String token) {
    var cookie =
        ResponseCookie.from("telugu_tunes_session", token)
            .httpOnly(true)
            .secure(true)
            .sameSite("None")
            .path("/")
            .maxAge(Duration.ofDays(30))
            .build();
    response.addHeader(HttpHeaders.SET_COOKIE, cookie.toString());
  }
}
