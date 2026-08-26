package com.telugutunes.api.service;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class SongQueryCleanerTest {
  private final SongQueryCleaner cleaner = new SongQueryCleaner();

  @Test
  void removesVideoPromotionTextBeforeCatalogSearch() {
    assertThat(cleaner.clean("Kurivippina 4K Video Song | Telugu Movie | 90sHD"))
        .isEqualTo("Kurivippina");
  }

  @Test
  void preservesTeluguSongNames() {
    assertThat(cleaner.clean("అనువనువూ Lyrical Video | Om Bheem Bush"))
        .isEqualTo("అనువనువూ");
  }
}
