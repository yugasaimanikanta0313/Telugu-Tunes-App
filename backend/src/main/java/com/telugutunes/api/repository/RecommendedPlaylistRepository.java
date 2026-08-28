package com.telugutunes.api.repository;

import com.telugutunes.api.domain.RecommendedPlaylistDocument;
import java.util.List;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface RecommendedPlaylistRepository extends MongoRepository<RecommendedPlaylistDocument, String> {
  List<RecommendedPlaylistDocument> findByActiveTrueOrderByUpdatedAtDesc();
}
