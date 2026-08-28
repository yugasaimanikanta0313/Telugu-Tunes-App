package com.telugutunes.api.service.lyrics;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import org.junit.jupiter.api.Test;

class LyricsifyParserTest {
  private final LyricsifyParser parser = new LyricsifyParser();

  @Test
  void parsesLegacySearchFixture() {
    var html = "<div class='li' data-album='Devara' data-duration='3:44'>"
        + "<a href='/lyrics/chuttamalle'>Chuttamalle - Shilpa Rao</a></div>";
    var results = parser.searchResults(html, URI.create("https://www.lyricsify.com/"));
    assertThat(results).singleElement().satisfies(result -> {
      assertThat(result.title()).isEqualTo("Chuttamalle");
      assertThat(result.artist()).isEqualTo("Shilpa Rao");
      assertThat(result.durationSeconds()).isEqualTo(224);
    });
  }

  @Test
  void extractsDisplayedSyncedLyrics() {
    var html = "<div id='entry'>[00:01.00]మొదటి\n[00:02.00]రెండవ</div>";
    assertThat(parser.extract(html, URI.create("https://www.lyricsify.com/song")).lrc()).isPresent();
  }

  @Test
  void findsRawLrcDownloadLink() {
    var html = "<a class='download-lrc' href='/files/song.lrc'>Download</a>";
    assertThat(parser.extract(html, URI.create("https://www.lyricsify.com/song")).rawLrcUri())
        .contains(URI.create("https://www.lyricsify.com/files/song.lrc"));
  }

  @Test
  void ignoresPlainTextPage() {
    var html = "<div id='entry'>ordinary lyrics without timestamps</div>";
    assertThat(parser.extract(html, URI.create("https://www.lyricsify.com/song")).lrc()).isEmpty();
  }
}
