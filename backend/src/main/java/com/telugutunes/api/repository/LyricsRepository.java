package com.telugutunes.api.repository;

import com.telugutunes.api.domain.LyricsDocument;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface LyricsRepository extends MongoRepository<LyricsDocument, String> {}
