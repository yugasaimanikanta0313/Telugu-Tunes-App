package com.telugutunes.api.repository;

import com.telugutunes.api.domain.RecommendationVoteDocument;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface RecommendationVoteRepository extends MongoRepository<RecommendationVoteDocument, String> {
  Optional<RecommendationVoteDocument> findByMemberIdAndTrackIdAndRecommendedPlaylistId(
      String memberId, String trackId, String recommendedPlaylistId);
  List<RecommendationVoteDocument> findByStatusOrderByUpdatedAtDesc(String status);
  List<RecommendationVoteDocument> findByTrackIdAndRecommendedPlaylistIdAndStatus(
      String trackId, String recommendedPlaylistId, String status);
}
