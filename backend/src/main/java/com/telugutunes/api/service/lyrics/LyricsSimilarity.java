package com.telugutunes.api.service.lyrics;

import java.util.Locale;

public final class LyricsSimilarity {
  private LyricsSimilarity() {}

  public static String normalize(String value) {
    return (value == null ? "" : value).toLowerCase(Locale.ROOT)
        .replace('’', '\'').replace('–', '-').replace('—', '-')
        .replaceAll("(?i)\\b(official video|video song|lyrical|full video|official|video|lyrics?|full|telugu|audio|hd|4k)\\b", " ")
        .replaceAll("[^\\p{L}\\p{N}]+", " ").trim().replaceAll("\\s+", " ");
  }

  public static double score(String expected, String candidate) {
    var left = normalize(expected);
    var right = normalize(candidate);
    if (left.isBlank() || right.isBlank()) return 0;
    if (left.equals(right)) return 1;
    var distance = levenshtein(left, right);
    var edit = 1.0 - ((double) distance / Math.max(left.length(), right.length()));
    if (left.contains(right) || right.contains(left)) edit = Math.max(edit, 0.85);
    return Math.max(0, Math.min(1, edit));
  }

  private static int levenshtein(String left, String right) {
    var previous = new int[right.length() + 1];
    for (var index = 0; index <= right.length(); index++) previous[index] = index;
    for (var row = 1; row <= left.length(); row++) {
      var current = new int[right.length() + 1]; current[0] = row;
      for (var column = 1; column <= right.length(); column++) {
        var cost = left.charAt(row - 1) == right.charAt(column - 1) ? 0 : 1;
        current[column] = Math.min(Math.min(current[column - 1] + 1, previous[column] + 1), previous[column - 1] + cost);
      }
      previous = current;
    }
    return previous[right.length()];
  }
}
