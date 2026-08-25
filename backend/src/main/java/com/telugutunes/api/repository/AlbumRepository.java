package com.telugutunes.api.repository;

import com.telugutunes.api.domain.AlbumDocument;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface AlbumRepository extends MongoRepository<AlbumDocument, String> {}
