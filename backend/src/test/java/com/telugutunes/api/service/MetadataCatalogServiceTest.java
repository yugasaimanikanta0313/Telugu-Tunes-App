package com.telugutunes.api.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.telugutunes.api.config.AppProperties;
import com.telugutunes.api.domain.TrackDocument;
import com.telugutunes.api.repository.MetadataCatalogRepository;
import com.telugutunes.api.repository.TrackRepository;
import java.io.ByteArrayInputStream;
import java.time.Instant;
import java.util.List;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;
import software.amazon.awssdk.services.s3.S3Client;

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

  @Test
  void exportsCurrentTracksAsExcelCatalog() throws Exception {
    var tracks = mock(TrackRepository.class);
    var auth = mock(AuthService.class);
    when(tracks.findAll()).thenReturn(List.of(new TrackDocument(
        "track-1", "Sivamruthavani", "Various Artists", "Lord Shiva", "lord-shiva",
        "23:58", 1438, "7C4DFF", "Various Artists", "Traditional", "Devotional",
        "https://example.com/cover.jpg", "", "audio-id", "audio/mpeg", "admin",
        Instant.now())));
    @SuppressWarnings("unchecked")
    ObjectProvider<S3Client> s3 = mock(ObjectProvider.class);
    var service = new MetadataCatalogService(mock(MetadataCatalogRepository.class), tracks,
        auth, s3, new AppProperties());

    var bytes = service.exportCurrentSongs("admin");

    verify(auth).requireAdministrator("admin");
    try (var workbook = new XSSFWorkbook(new ByteArrayInputStream(bytes))) {
      var sheet = workbook.getSheet("Music Metadata Catalog");
      assertThat(sheet.getRow(1).getCell(0).getStringCellValue())
          .isEqualTo("Sivamruthavani");
      assertThat(sheet.getRow(1).getCell(2).getStringCellValue())
          .isEqualTo("Lord Shiva");
    }
  }
}
