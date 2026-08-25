package com.telugutunes.api.repository;

import com.telugutunes.api.domain.TrackDocument;
import java.util.List;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface TrackRepository extends MongoRepository<TrackDocument, String> {
  List<TrackDocument> findTop40ByTitleContainingIgnoreCaseOrArtistContainingIgnoreCaseOrAlbumContainingIgnoreCase(
      String title, String artist, String album);
}
