package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.MetadataCatalogImportResponse;
import com.telugutunes.api.config.AppProperties;
import com.telugutunes.api.domain.MetadataCatalogEntry;
import com.telugutunes.api.repository.MetadataCatalogRepository;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.text.Normalizer;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.DataFormatter;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

@Service
public class MetadataCatalogService {
  public static final String OBJECT_KEY = "metadata/catalog/music_metadata_catalog.xlsx";
  private static final List<String> HEADERS = List.of(
      "song name", "primary artist", "album", "singers", "music director", "genre");

  private final MetadataCatalogRepository repository;
  private final AuthService auth;
  private final ObjectProvider<S3Client> s3Provider;
  private final AppProperties properties;

  public MetadataCatalogService(MetadataCatalogRepository repository, AuthService auth,
      ObjectProvider<S3Client> s3Provider, AppProperties properties) {
    this.repository = repository;
    this.auth = auth;
    this.s3Provider = s3Provider;
    this.properties = properties;
  }

  public MetadataCatalogImportResponse upload(String administratorId, MultipartFile file) {
    auth.requireAdministrator(administratorId);
    if (file == null || file.isEmpty()) throw new IllegalArgumentException("Choose a non-empty .xlsx file.");
    int imported = 0;
    int updated = 0;
    try (Workbook workbook = new XSSFWorkbook(new ByteArrayInputStream(file.getBytes()))) {
      Sheet sheet = workbook.getSheetAt(0);
      DataFormatter formatter = new DataFormatter();
      Row header = sheet.getRow(sheet.getFirstRowNum());
      Map<String, Integer> columns = new HashMap<>();
      for (Cell cell : header) columns.put(normalizeHeader(formatter.formatCellValue(cell)), cell.getColumnIndex());
      for (String required : HEADERS) {
        if (!columns.containsKey(required)) throw new IllegalArgumentException("Missing Excel column: " + required);
      }
      for (int index = header.getRowNum() + 1; index <= sheet.getLastRowNum(); index++) {
        Row row = sheet.getRow(index);
        if (row == null) continue;
        String song = value(row, columns.get("song name"), formatter);
        if (song.isBlank()) continue;
        String album = value(row, columns.get("album"), formatter);
        String singers = value(row, columns.get("singers"), formatter);
        String director = value(row, columns.get("music director"), formatter);
        String id = stableKey(song, album, singers, director);
        boolean exists = repository.existsById(id);
        repository.save(new MetadataCatalogEntry(id, song,
            value(row, columns.get("primary artist"), formatter), album, singers, director,
            value(row, columns.get("genre"), formatter), normalizeSong(song), Instant.now()));
        if (exists) updated++; else imported++;
      }
      byte[] canonical = exportWorkbook(repository.findAll());
      boolean stored = storeInBucket(canonical);
      long total = repository.count();
      return new MetadataCatalogImportResponse(imported, updated, total, stored, OBJECT_KEY,
          stored ? "Catalog merged and saved to Oracle Object Storage."
              : "Catalog merged. Oracle Object Storage is not configured on this server.");
    } catch (IllegalArgumentException exception) {
      throw exception;
    } catch (Exception exception) {
      throw new IllegalStateException("Could not import metadata catalog: " + exception.getMessage(), exception);
    }
  }

  public Optional<MetadataCatalogEntry> match(String fileName) {
    String query = normalizeSong(fileName);
    Optional<MetadataCatalogEntry> exact = repository.findFirstByNormalizedSongName(query);
    if (exact.isPresent()) return exact;
    List<MetadataCatalogEntry> entries = repository.findAll();
    Optional<MetadataCatalogEntry> contained = entries.stream()
        .filter(entry -> !query.isBlank() && (query.contains(entry.normalizedSongName())
            || entry.normalizedSongName().contains(query)))
        .max(java.util.Comparator.comparingInt(entry -> entry.normalizedSongName().length()));
    if (contained.isPresent()) return contained;
    if (query.length() < 4) return Optional.empty();
    return entries.stream()
        .map(entry -> Map.entry(entry, similarity(query, entry.normalizedSongName())))
        .filter(candidate -> candidate.getValue() >= 0.72)
        .max(Map.Entry.comparingByValue())
        .map(Map.Entry::getKey);
  }

  static double similarity(String left, String right) {
    if (left.equals(right)) return 1.0;
    int longest = Math.max(left.length(), right.length());
    if (longest == 0) return 1.0;
    int[] previous = new int[right.length() + 1];
    int[] current = new int[right.length() + 1];
    for (int column = 0; column <= right.length(); column++) previous[column] = column;
    for (int row = 1; row <= left.length(); row++) {
      current[0] = row;
      for (int column = 1; column <= right.length(); column++) {
        int cost = left.charAt(row - 1) == right.charAt(column - 1) ? 0 : 1;
        current[column] = Math.min(Math.min(current[column - 1] + 1,
            previous[column] + 1), previous[column - 1] + cost);
      }
      int[] swap = previous;
      previous = current;
      current = swap;
    }
    return 1.0 - ((double) previous[right.length()] / longest);
  }

  static String normalizeSong(String input) {
    if (input == null) return "";
    String noExtension = input.replaceFirst("(?i)\\.(mp3|m4a|aac|wav|flac|ogg)$", "");
    String noTrack = noExtension.replaceFirst("^\\s*\\d+[\\s._-]+", "");
    return Normalizer.normalize(noTrack, Normalizer.Form.NFKD).toLowerCase(Locale.ROOT)
        .replaceAll("\\([^)]*\\)|\\[[^]]*]", " ").replaceAll("[^\\p{L}\\p{N}]+", " ").trim();
  }

  private static String normalizeHeader(String value) {
    return value.toLowerCase(Locale.ROOT).replaceAll("[_-]+", " ").replaceAll("\\s+", " ").trim();
  }

  private static String value(Row row, int column, DataFormatter formatter) {
    Cell cell = row.getCell(column, Row.MissingCellPolicy.RETURN_BLANK_AS_NULL);
    return cell == null ? "" : formatter.formatCellValue(cell).trim();
  }

  private static String stableKey(String... values) {
    return java.util.UUID.nameUUIDFromBytes(String.join("|", values).toLowerCase(Locale.ROOT)
        .getBytes(java.nio.charset.StandardCharsets.UTF_8)).toString();
  }

  private byte[] exportWorkbook(List<MetadataCatalogEntry> entries) throws Exception {
    try (Workbook workbook = new XSSFWorkbook(); ByteArrayOutputStream output = new ByteArrayOutputStream()) {
      Sheet sheet = workbook.createSheet("Music Metadata Catalog");
      Row header = sheet.createRow(0);
      for (int i = 0; i < HEADERS.size(); i++) header.createCell(i).setCellValue(titleCase(HEADERS.get(i)));
      int rowIndex = 1;
      for (MetadataCatalogEntry entry : entries) {
        Row row = sheet.createRow(rowIndex++);
        row.createCell(0).setCellValue(entry.songName());
        row.createCell(1).setCellValue(entry.primaryArtist());
        row.createCell(2).setCellValue(entry.album());
        row.createCell(3).setCellValue(entry.singers());
        row.createCell(4).setCellValue(entry.musicDirector());
        row.createCell(5).setCellValue(entry.genre());
      }
      sheet.createFreezePane(0, 1);
      for (int i = 0; i < HEADERS.size(); i++) sheet.autoSizeColumn(i);
      workbook.write(output);
      return output.toByteArray();
    }
  }

  private boolean storeInBucket(byte[] bytes) {
    S3Client s3 = s3Provider.getIfAvailable();
    if (s3 == null || !properties.getStorage().getR2().isEnabled()) return false;
    s3.putObject(PutObjectRequest.builder().bucket(properties.getStorage().getR2().getBucket())
        .key(OBJECT_KEY).contentType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        .build(), RequestBody.fromBytes(bytes));
    return true;
  }

  private static String titleCase(String value) {
    return java.util.Arrays.stream(value.split(" ")).map(word -> Character.toUpperCase(word.charAt(0)) + word.substring(1))
        .collect(java.util.stream.Collectors.joining(" "));
  }
}
