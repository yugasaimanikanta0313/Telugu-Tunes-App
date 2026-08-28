package com.telugutunes.api.service.lyrics;

import java.net.URI;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Element;
import org.springframework.stereotype.Component;

@Component
public class LyricsifyParser {
  static final String RESULT_SELECTORS = "div.li, .search-result, .result, article";
  static final String LRC_SELECTORS = "#entry, pre.lrc, pre, textarea[name=lrc], textarea.lrc, [data-lrc]";

  public List<Candidate> searchResults(String html, URI baseUri) {
    var document = Jsoup.parse(html, baseUri.toString());
    var results = new ArrayList<Candidate>();
    for (var element : document.select(RESULT_SELECTORS)) {
      var link = element.selectFirst("a[href]");
      if (link == null) continue;
      var title = text(element, ".song-title, .title, h2, h3");
      if (title.isBlank()) title = link.text();
      var artist = firstNonBlank(element.attr("data-artist"), text(element, ".artist, .singer"));
      var album = firstNonBlank(element.attr("data-album"), text(element, ".album, .release"));
      var duration = duration(firstNonBlank(element.attr("data-duration"), text(element, ".duration, time")));
      // Older Lyricsify pages place "title - artist" only in the anchor text.
      if (artist.isBlank()) {
        var parts = link.text().split("\\s+[-–—]\\s+", 2);
        if (parts.length == 2) { title = parts[0]; artist = parts[1]; }
      }
      try {
        results.add(new Candidate(title, artist, album, duration, URI.create(link.absUrl("href"))));
      } catch (IllegalArgumentException ignored) {
        // Ignore malformed third-party links.
      }
    }
    return results;
  }

  public ExtractedPage extract(String html, URI baseUri) {
    var document = Jsoup.parse(html, baseUri.toString());
    for (var selector : LRC_SELECTORS.split(", ")) {
      var element = document.selectFirst(selector);
      if (element == null) continue;
      var value = element.hasAttr("data-lrc") ? element.attr("data-lrc") : element.wholeText();
      if (LrcValidator.isSynced(value)) return new ExtractedPage(Optional.of(value.trim()), Optional.empty());
    }
    for (var link : document.select("a[href][download], a[href$=.lrc], a.raw-lrc[href], a.download-lrc[href]")) {
      try {
        return new ExtractedPage(Optional.empty(), Optional.of(URI.create(link.absUrl("href"))));
      } catch (IllegalArgumentException ignored) {}
    }
    return new ExtractedPage(Optional.empty(), Optional.empty());
  }

  private String text(Element element, String selector) {
    var match = element.selectFirst(selector);
    return match == null ? "" : match.text().trim();
  }

  private String firstNonBlank(String first, String second) {
    return first == null || first.isBlank() ? (second == null ? "" : second) : first;
  }

  private int duration(String value) {
    if (value == null || value.isBlank()) return 0;
    try {
      var parts = value.trim().split(":");
      return parts.length == 2 ? Integer.parseInt(parts[0]) * 60 + Integer.parseInt(parts[1]) : Integer.parseInt(value);
    } catch (NumberFormatException ignored) { return 0; }
  }

  public record Candidate(String title, String artist, String album, int durationSeconds, URI uri) {}
  public record ExtractedPage(Optional<String> lrc, Optional<URI> rawLrcUri) {}
}
