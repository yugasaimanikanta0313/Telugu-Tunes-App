package com.telugutunes.api.service;

import java.io.IOException;
import java.io.OutputStream;
import org.springframework.web.multipart.MultipartFile;

public interface MediaStorageService {
  String providerName();

  StoredMedia upload(MultipartFile source) throws IOException;

  StoredMediaInfo mediaInfo(String objectId) throws IOException;

  void stream(String objectId, long start, long end, OutputStream target) throws IOException;

  void delete(String objectId) throws IOException;

  record StoredMedia(String objectId, String fileName, String mimeType) {}

  record StoredMediaInfo(long size, String mimeType) {}
}
