package com.telugutunes.api.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.telugutunes.api.config.AppProperties;
import com.telugutunes.api.domain.LyricsDocument;
import com.telugutunes.api.domain.TrackDocument;
import com.telugutunes.api.repository.LyricsRepository;
import com.telugutunes.api.service.lyrics.LyricsProvider;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class LyricsServiceTest {
  private LyricsRepository repository;
  private CatalogService catalog;
  private AuthService auth;
  private LyricsProvider lrclib;
  private LyricsProvider lyricsify;

  @BeforeEach
  void setUp() {
    repository = mock(LyricsRepository.class);
    catalog = mock(CatalogService.class);
    auth = mock(AuthService.class);
    lrclib = mock(LyricsProvider.class);
    lyricsify = mock(LyricsProvider.class);
    when(lrclib.name()).thenReturn("lrclib");
    when(lyricsify.name()).thenReturn("lyricsify");
    when(catalog.trackDocument("track-1")).thenReturn(mock(TrackDocument.class));
    when(repository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));
  }

  @Test
  void cachedSyncedLyricsAvoidAllNetworkProviders() {
    when(repository.findById("track-1")).thenReturn(Optional.of(document("manual")));

    var response = service().get("track-1");

    assertThat(response.source()).isEqualTo("manual");
    verify(lrclib, never()).find(any());
    verify(lyricsify, never()).find(any());
  }

  @Test
  void lrclibSuccessSkipsLyricsify() {
    when(repository.findById("track-1")).thenReturn(Optional.empty());
    when(lrclib.find(any())).thenReturn(Optional.of(match("lrclib")));

    var response = service().get("track-1");

    assertThat(response.source()).isEqualTo("lrclib");
    verify(lyricsify, never()).find(any());
  }

  @Test
  void lyricsifyRunsOnlyAfterLrclibMiss() {
    when(repository.findById("track-1")).thenReturn(Optional.empty());
    when(lrclib.find(any())).thenReturn(Optional.empty());
    when(lyricsify.find(any())).thenReturn(Optional.of(match("lyricsify")));

    var response = service().get("track-1");

    assertThat(response.source()).isEqualTo("lyricsify");
    verify(lrclib).find(any());
    verify(lyricsify).find(any());
  }

  @Test
  void bothProviderFailuresAreCachedAsUnavailable() {
    when(repository.findById("track-1")).thenReturn(Optional.empty());
    when(lrclib.find(any())).thenReturn(Optional.empty());
    when(lyricsify.find(any())).thenReturn(Optional.empty());

    var response = service().get("track-1");

    assertThat(response.source()).isEqualTo("unavailable");
    verify(repository).save(any(LyricsDocument.class));
  }

  @Test
  void duplicateCallsReuseNegativeCache() {
    var unavailable = new LyricsDocument("track-1", "te", "unavailable", "", "",
        "", "", null, 0.0, "system", Instant.now());
    when(repository.findById("track-1"))
        .thenReturn(Optional.empty())
        .thenReturn(Optional.of(unavailable));
    when(lrclib.find(any())).thenReturn(Optional.empty());
    when(lyricsify.find(any())).thenReturn(Optional.empty());

    service().get("track-1");
    service().get("track-1");

    verify(lrclib).find(any());
    verify(lyricsify).find(any());
  }

  private LyricsService service() {
    return new LyricsService(repository, catalog, auth, List.of(lrclib, lyricsify), new AppProperties());
  }

  private LyricsProvider.LyricsMatch match(String source) {
    return new LyricsProvider.LyricsMatch(source, "https://example.test/lrc",
        "మొదటి\nరెండవ", "[00:01.00]మొదటి\n[00:02.00]రెండవ", 0.95);
  }

  private LyricsDocument document(String source) {
    return new LyricsDocument("track-1", "te", source, "మొదటి\nరెండవ",
        "[00:01.00]మొదటి\n[00:02.00]రెండవ", "", "", null, 1.0, "member-1", Instant.now());
  }
}
