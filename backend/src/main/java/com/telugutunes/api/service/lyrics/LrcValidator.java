package com.telugutunes.api.service.lyrics;

import java.util.regex.Pattern;

public final class LrcValidator {
  private static final Pattern LINE = Pattern.compile("^\\s*\\[\\d{1,3}:\\d{2}(?:[.:]\\d{1,3})?].*\\S.*$");

  private LrcValidator() {}

  public static boolean isSynced(String value) {
    if (value == null || value.isBlank() || value.toLowerCase().contains("<html")) return false;
    return value.lines().filter(line -> LINE.matcher(line).matches()).limit(2).count() >= 2;
  }

  public static String plainText(String lrc) {
    if (lrc == null) return "";
    return lrc.lines()
        .map(line -> line.replaceFirst("^(?:\\s*\\[\\d{1,3}:\\d{2}(?:[.:]\\d{1,3})?])+\\s*", ""))
        .filter(line -> !line.isBlank() && !line.matches("^\\[[a-zA-Z]+:.*]$"))
        .reduce((left, right) -> left + "\n" + right)
        .orElse("");
  }
}
