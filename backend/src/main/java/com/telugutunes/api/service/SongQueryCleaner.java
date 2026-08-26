package com.telugutunes.api.service;

import java.util.Arrays;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

/** Removes common video/channel promotion text before searching music catalogues. */
@Component
public class SongQueryCleaner {
  private static final Pattern NOISE = Pattern.compile(
      "(?i)\\b(?:official|full|latest|new)?\\s*(?:4k|8k|uhd|full\\s*hd|hd|1080p|720p|"
          + "video\\s*song|lyrical\\s*(?:video|song)?|official\\s*video|audio\\s*song|"
          + "5\\.1\\s*audio|dolby\\s*atmos|jukebox|whatsapp\\s*status|shorts?|"
          + "90s\\s*hd|telugu\\s*video\\s*song)\\b");
  private static final Pattern BRACKETED_NOISE = Pattern.compile(
      "(?i)[\\[(][^\\])]*(?:4k|8k|hd|official|lyrical|video|audio|status|views?)[^\\])]*[\\])]");

  public String clean(String value) {
    if (value == null || value.isBlank()) return "";
    var withoutUrl = value.replaceAll("https?://\\S+", " ");
    var segments = Arrays.stream(withoutUrl.split("[|•]"))
        .map(this::cleanSegment)
        .filter(segment -> !segment.isBlank())
        .toList();
    if (segments.isEmpty()) return cleanSegment(withoutUrl);
    // Upload titles conventionally put the actual song name before channel and credit sections.
    return segments.getFirst();
  }

  private String cleanSegment(String value) {
    return NOISE.matcher(BRACKETED_NOISE.matcher(value).replaceAll(" ")).replaceAll(" ")
        .replaceAll("(?i)\\b(?:million|views?|subscribe|channel)\\b", " ")
        .replaceAll("#[\\p{L}\\p{M}\\p{N}_]+", " ")
        .replaceAll("[^\\p{L}\\p{M}\\p{N}'&()\\-\\s]", " ")
        .replaceAll("\\s+", " ")
        .replaceAll("^[\\s\\-–—:]+|[\\s\\-–—:]+$", "")
        .trim();
  }
}
