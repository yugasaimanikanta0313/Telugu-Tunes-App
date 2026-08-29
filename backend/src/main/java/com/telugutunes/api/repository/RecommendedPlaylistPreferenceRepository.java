package com.telugutunes.api.repository;

import com.telugutunes.api.domain.RecommendedPlaylistPreferenceDocument;
import java.util.List;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface RecommendedPlaylistPreferenceRepository
    extends MongoRepository<RecommendedPlaylistPreferenceDocument, String> {
  List<RecommendedPlaylistPreferenceDocument> findAllByMemberId(String memberId);
}
