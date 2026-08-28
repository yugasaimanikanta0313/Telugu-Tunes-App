package com.telugutunes.api.service.lyrics;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class LrcValidatorTest {
  @Test
  void acceptsTimestampedLrc() {
    assertThat(LrcValidator.isSynced("[00:01.00]మొదటి పాదం\n[00:05.20]రెండవ పాదం")).isTrue();
  }

  @Test
  void rejectsPlainLyrics() {
    assertThat(LrcValidator.isSynced("మొదటి పాదం\nరెండవ పాదం")).isFalse();
  }

  @Test
  void rejectsHtmlChallengePage() {
    assertThat(LrcValidator.isSynced("<html>\n[00:01.00]fake\n[00:02.00]fake</html>")).isFalse();
  }

  @Test
  void derivesPlainLyricsFromLrc() {
    assertThat(LrcValidator.plainText("[ar:Artist]\n[00:01.00]మొదటి\n[00:02.00]రెండవ"))
        .isEqualTo("మొదటి\nరెండవ");
  }
}
