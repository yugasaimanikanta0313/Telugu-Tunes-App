package com.telugutunes.api.repository;

import com.telugutunes.api.domain.RecommendedPlaylistDocument;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface RecommendedPlaylistRepository extends MongoRepository<RecommendedPlaylistDocument, String> {
  List<RecommendedPlaylistDocument> findByActiveTrueOrderByUpdatedAtDesc();
  Optional<RecommendedPlaylistDocument> findFirstByNameIgnoreCaseAndTypeIgnoreCaseAndSubtypeIgnoreCase(
      String name, String type, String subtype);
}
