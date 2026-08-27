package com.telugutunes.api.config;

import com.telugutunes.api.service.AuthService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/** Protects write and social features with an opaque, server-stored session token. */
@Component
public class AuthenticationFilter extends OncePerRequestFilter {
  public static final String MEMBER_ID_ATTRIBUTE = "authenticatedMemberId";
  private final AuthService auth;

  public AuthenticationFilter(AuthService auth) {
    this.auth = auth;
  }

  @Override
  protected boolean shouldNotFilter(HttpServletRequest request) {
    var path = request.getRequestURI();
    var publicCatalogRead =
        "GET".equalsIgnoreCase(request.getMethod())
            && (path.startsWith("/api/v1/home")
                || path.startsWith("/api/v1/albums")
                || path.startsWith("/api/v1/tracks/search"));
    var ticketedAudioRead =
        "GET".equalsIgnoreCase(request.getMethod())
            && path.startsWith("/api/v1/audio/")
            && !path.endsWith("/ticket")
            && request.getParameter("ticket") != null;
    return "OPTIONS".equalsIgnoreCase(request.getMethod())
        || !path.startsWith("/api/v1/")
        || path.startsWith("/api/v1/auth/")
        || publicCatalogRead
        || ticketedAudioRead
        || path.startsWith("/api/v1/storage/google-drive/")
        || path.startsWith("/actuator/");
  }

  @Override
  protected void doFilterInternal(
      HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
      throws ServletException, IOException {
    var header = request.getHeader("Authorization");
    var token = header != null && header.startsWith("Bearer ") ? header.substring(7).trim() : cookie(request);
    if (token == null || token.isBlank()) {
      unauthorized(response, "Sign in is required.");
      return;
    }
    try {
      var member = auth.memberForToken(token);
      request.setAttribute(MEMBER_ID_ATTRIBUTE, member.id());
      filterChain.doFilter(request, response);
    } catch (IllegalArgumentException exception) {
      unauthorized(response, exception.getMessage());
    }
  }

  private void unauthorized(HttpServletResponse response, String message) throws IOException {
    response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
    response.setContentType(MediaType.APPLICATION_JSON_VALUE);
    response.getWriter().write("{\"status\":401,\"message\":\"" + message.replace("\"", "") + "\"}");
  }

  private String cookie(HttpServletRequest request) {
    var cookies = request.getCookies();
    if (cookies == null) return null;
    for (var cookie : cookies) {
      if ("telugu_tunes_session".equals(cookie.getName())) return cookie.getValue();
    }
    return null;
  }
}
