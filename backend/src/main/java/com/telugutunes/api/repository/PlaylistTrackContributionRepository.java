package com.telugutunes.api.repository;

import com.telugutunes.api.domain.PlaylistTrackContributionDocument;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface PlaylistTrackContributionRepository
    extends MongoRepository<PlaylistTrackContributionDocument, String> {
  List<PlaylistTrackContributionDocument> findByPlaylistId(String playlistId);

  Optional<PlaylistTrackContributionDocument> findByPlaylistIdAndTrackId(
      String playlistId, String trackId);

  void deleteByPlaylistId(String playlistId);
}
