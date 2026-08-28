package com.telugutunes.api.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.telugutunes.api.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;

class AuthenticationFilterTest {
  private final TestFilter filter = new TestFilter(mock(AuthService.class));

  @Test
  void guestCanReadCatalogLyricsAndRequestPlaybackTicket() {
    assertThat(filter.skips(request("GET", "/api/v1/tracks/t1/lyrics"))).isTrue();
    assertThat(filter.skips(request("GET", "/api/v1/audio/t1/ticket"))).isTrue();
  }

  @Test
  void roomsAndPersonalPlaylistsRemainProtected() {
    assertThat(filter.skips(request("GET", "/api/v1/rooms"))).isFalse();
    assertThat(filter.skips(request("GET", "/api/v1/playlists"))).isFalse();
  }

  private HttpServletRequest request(String method, String path) {
    var request = mock(HttpServletRequest.class);
    when(request.getMethod()).thenReturn(method);
    when(request.getRequestURI()).thenReturn(path);
    return request;
  }

  private static class TestFilter extends AuthenticationFilter {
    TestFilter(AuthService auth) { super(auth); }
    boolean skips(HttpServletRequest request) { return shouldNotFilter(request); }
  }
}
