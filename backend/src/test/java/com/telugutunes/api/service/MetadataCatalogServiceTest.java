package com.telugutunes.api.service;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class MetadataCatalogServiceTest {
  @Test
  void acceptsSmallSpellingDifferencesForExcelCatalogMatching() {
    String uploadedTitle = MetadataCatalogService.normalizeSong("Bhoom Shakana");
    String audioFileName = MetadataCatalogService.normalizeSong("Bhoom Shakenaka.mp3");

    assertThat(MetadataCatalogService.similarity(audioFileName, uploadedTitle))
        .isGreaterThanOrEqualTo(0.72);
  }

  @Test
  void rejectsUnrelatedTitles() {
    assertThat(MetadataCatalogService.similarity("bhoom shakenaka", "sada siva"))
        .isLessThan(0.72);
  }
}
