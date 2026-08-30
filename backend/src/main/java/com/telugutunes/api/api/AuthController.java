package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.AuthResponse;
import com.telugutunes.api.api.dto.LoginRequest;
import com.telugutunes.api.api.dto.RegisterRequest;
import com.telugutunes.api.service.AuthService;
import com.telugutunes.api.service.PasswordResetService;
import com.telugutunes.api.api.dto.ForgotPasswordRequest;
import com.telugutunes.api.api.dto.PasswordResetMessageResponse;
import com.telugutunes.api.api.dto.ResetPasswordRequest;
import com.telugutunes.api.api.dto.VerifyResetOtpRequest;
import com.telugutunes.api.api.dto.VerifyResetOtpResponse;
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
  private final PasswordResetService passwordResets;

  public AuthController(AuthService auth, PasswordResetService passwordResets) {
    this.auth = auth;
    this.passwordResets = passwordResets;
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

  @PostMapping("/forgot-password")
  public PasswordResetMessageResponse forgotPassword(@Valid @RequestBody ForgotPasswordRequest request) {
    passwordResets.request(request.email());
    return new PasswordResetMessageResponse("If that account exists, a six-digit code has been sent.");
  }

  @PostMapping("/verify-reset-otp")
  public VerifyResetOtpResponse verifyResetOtp(@Valid @RequestBody VerifyResetOtpRequest request) {
    return new VerifyResetOtpResponse(passwordResets.verify(request));
  }

  @PostMapping("/reset-password")
  public PasswordResetMessageResponse resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
    passwordResets.reset(request);
    return new PasswordResetMessageResponse("Password updated. Sign in with your new password.");
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
