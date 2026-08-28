package com.telugutunes.api.service.lyrics;

import static org.assertj.core.api.Assertions.assertThat;

import com.telugutunes.api.config.AppProperties;
import com.telugutunes.api.domain.TrackDocument;
import java.net.URI;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class LyricsifyLyricsProviderTest {
  @Test
  void acceptsStrongMatchFromMockedHtmlFixtures() {
    var fetcher = new FixtureFetcher();
    fetcher.search = "<div class='li' data-artist='Shilpa Rao' data-album='Devara' data-duration='3:44'>"
        + "<a href='/song/chuttamalle'><span class='title'>Chuttamalle</span></a></div>";
    fetcher.pages.put("https://www.lyricsify.com/song/chuttamalle",
        "<pre class='lrc'>[00:01.00]మొదటి\n[00:02.00]రెండవ</pre>");

    var result = provider(fetcher).find(track());

    assertThat(result).isPresent();
    assertThat(result.get().source()).isEqualTo("lyricsify");
    assertThat(result.get().syncedLyrics()).contains("[00:01.00]");
  }

  @Test
  void rejectsWrongArtistAndAlbum() {
    var fetcher = new FixtureFetcher();
    fetcher.search = "<div class='li' data-artist='Wrong Artist' data-album='Wrong Movie' data-duration='8:00'>"
        + "<a href='/song/wrong'><span class='title'>Chuttamalle</span></a></div>";
    assertThat(provider(fetcher).find(track())).isEmpty();
  }

  @Test
  void rejectsValidMetadataWhenPageHasOnlyPlainLyrics() {
    var fetcher = new FixtureFetcher();
    fetcher.search = "<div class='li' data-artist='Shilpa Rao' data-album='Devara' data-duration='3:44'>"
        + "<a href='/song/plain'><span class='title'>Chuttamalle</span></a></div>";
    fetcher.pages.put("https://www.lyricsify.com/song/plain", "<div id='entry'>plain lyrics</div>");
    assertThat(provider(fetcher).find(track())).isEmpty();
  }

  @Test
  void networkFailureBehavesAsProviderMiss() {
    assertThat(provider(uri -> Optional.empty()).find(track())).isEmpty();
  }

  private LyricsifyLyricsProvider provider(LyricsifyPageFetcher fetcher) {
    return new LyricsifyLyricsProvider(fetcher, new LyricsifyParser(), new AppProperties());
  }

  private TrackDocument track() {
    return new TrackDocument("track-1", "Chuttamalle", "T-Series Telugu", "Devara", "album-1",
        "3:44", 224, "#000000", "Shilpa Rao", "Anirudh", "Romantic", "", "", "", "audio/mpeg",
        "member-1", Instant.now());
  }

  private static class FixtureFetcher implements LyricsifyPageFetcher {
    String search = "";
    final Map<String, String> pages = new HashMap<>();

    @Override
    public Optional<String> fetch(URI uri) {
      if (uri.getPath().equals("/search")) return Optional.ofNullable(search).filter(value -> !value.isBlank());
      return Optional.ofNullable(pages.get(uri.toString()));
    }
  }
}
