package com.telugutunes.api.repository;

import com.telugutunes.api.domain.MetadataCatalogEntry;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface MetadataCatalogRepository extends MongoRepository<MetadataCatalogEntry, String> {
  Optional<MetadataCatalogEntry> findFirstByNormalizedSongName(String normalizedSongName);
}
