package com.telugutunes.api.repository;

import com.telugutunes.api.domain.TrackDocument;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface TrackRepository extends MongoRepository<TrackDocument, String> {
}
