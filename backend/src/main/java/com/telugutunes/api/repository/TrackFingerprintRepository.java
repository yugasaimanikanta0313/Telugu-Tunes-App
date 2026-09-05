package com.telugutunes.api.repository;

import com.telugutunes.api.domain.TrackFingerprintDocument;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface TrackFingerprintRepository
    extends MongoRepository<TrackFingerprintDocument, String> {
  Optional<TrackFingerprintDocument> findByFileSha256(String fileSha256);
  void deleteByTrackId(String trackId);
}
