package com.telugutunes.api.service;

import com.google.api.client.http.FileContent;
import com.google.api.services.drive.Drive;
import com.google.api.services.drive.model.File;
import com.telugutunes.api.config.AppProperties;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
@ConditionalOnBean(Drive.class)
public class GoogleDriveStorageService implements MediaStorageService {
  private static final String APP_FOLDER_NAME = "Telugu Tunes Uploads (App)";
  private static final String FOLDER_MIME_TYPE = "application/vnd.google-apps.folder";

  private final Drive drive;
  private final AppProperties properties;
  private volatile String resolvedFolderId;

  public GoogleDriveStorageService(Drive drive, AppProperties properties) {
    this.drive = drive;
    this.properties = properties;
  }

  @Override
  public String providerName() {
    return "google-drive";
  }

  @Override
  public StoredMedia upload(MultipartFile source) throws IOException {
    var extension = safeFileName(source.getOriginalFilename());
    var contentType = source.getContentType() == null ? "audio/mpeg" : source.getContentType();
    Path temporaryFile = Files.createTempFile("telugu-tunes-upload-", "-" + extension);
    try {
      source.transferTo(temporaryFile);
      var metadata =
          new File()
              .setName(safeFileName(source.getOriginalFilename()))
              .setParents(List.of(storageFolderId()));
      var content = new FileContent(contentType, temporaryFile.toFile());
      var uploaded =
          drive.files()
              .create(metadata, content)
              .setFields("id,name,mimeType,size")
              .execute();
      return new StoredMedia(uploaded.getId(), uploaded.getName(), uploaded.getMimeType());
    } finally {
      Files.deleteIfExists(temporaryFile);
    }
  }

  @Override
  public StoredMediaInfo mediaInfo(String driveFileId) throws IOException {
    var file = drive.files().get(driveFileId).setFields("size,mimeType").execute();
    return new StoredMediaInfo(
        file.getSize() == null ? 0L : file.getSize(),
        file.getMimeType() == null ? "audio/mpeg" : file.getMimeType());
  }

  /** Streams only the requested byte range so browser and Android players can seek. */
  @Override
  public void stream(String driveFileId, long start, long end, OutputStream target) throws IOException {
    // The bundled Drive Java client exposes the lower-level media methods as protected. Its public
    // download helper is used with a bounded output stream: the client still receives only the
    // requested range and can therefore seek, while Drive may read the source from its beginning.
    drive.files().get(driveFileId).executeMediaAndDownloadTo(new ByteRangeOutputStream(target, start, end));
  }

  @Override
  public void delete(String driveFileId) throws IOException {
    if (driveFileId != null && !driveFileId.isBlank()) {
      drive.files().delete(driveFileId).execute();
    }
  }

  /**
   * With the narrow drive.file scope, a folder manually created in Drive is intentionally not
   * visible to this application. Reuse a configured folder when the application can access it;
   * otherwise create one that the owner can see in their Drive and that this application owns.
   */
  private String storageFolderId() throws IOException {
    var cached = resolvedFolderId;
    if (cached != null) {
      return cached;
    }

    synchronized (this) {
      if (resolvedFolderId != null) {
        return resolvedFolderId;
      }

      var configuredFolder = properties.getStorage().getGoogleDrive().getFolderId();
      if (configuredFolder != null && !configuredFolder.isBlank() && canAccess(configuredFolder)) {
        resolvedFolderId = configuredFolder;
        return resolvedFolderId;
      }

      var existing =
          drive.files()
              .list()
              .setQ(
                  "name = '"
                      + APP_FOLDER_NAME
                      + "' and mimeType = '"
                      + FOLDER_MIME_TYPE
                      + "' and trashed = false")
              .setPageSize(1)
              .setFields("files(id)")
              .execute()
              .getFiles();
      if (existing != null && !existing.isEmpty()) {
        resolvedFolderId = existing.getFirst().getId();
        return resolvedFolderId;
      }

      var created =
          drive.files()
              .create(new File().setName(APP_FOLDER_NAME).setMimeType(FOLDER_MIME_TYPE))
              .setFields("id")
              .execute();
      resolvedFolderId = created.getId();
      return resolvedFolderId;
    }
  }

  private boolean canAccess(String folderId) {
    try {
      drive.files().get(folderId).setFields("id").execute();
      return true;
    } catch (IOException exception) {
      return false;
    }
  }

  private String safeFileName(String fileName) {
    var candidate = fileName == null || fileName.isBlank() ? "uploaded-track.mp3" : fileName;
    return candidate.replaceAll("[^a-zA-Z0-9._ -]", "_");
  }

  private static final class ByteRangeOutputStream extends OutputStream {
    private final OutputStream target;
    private long bytesToSkip;
    private long bytesRemaining;

    private ByteRangeOutputStream(OutputStream target, long start, long end) {
      this.target = target;
      this.bytesToSkip = start;
      this.bytesRemaining = end - start + 1;
    }

    @Override
    public void write(int value) throws IOException {
      if (bytesToSkip > 0) {
        bytesToSkip--;
      } else if (bytesRemaining > 0) {
        target.write(value);
        bytesRemaining--;
      }
    }

    @Override
    public void write(byte[] buffer, int offset, int length) throws IOException {
      if (length <= 0 || bytesRemaining <= 0) return;
      var skipped = (int) Math.min(bytesToSkip, length);
      bytesToSkip -= skipped;
      var available = length - skipped;
      var count = (int) Math.min(bytesRemaining, available);
      if (count > 0) {
        target.write(buffer, offset + skipped, count);
        bytesRemaining -= count;
      }
    }

    @Override
    public void flush() throws IOException {
      target.flush();
    }

    @Override
    public void close() {
      // Tomcat owns the servlet output stream lifecycle.
    }
  }
}
