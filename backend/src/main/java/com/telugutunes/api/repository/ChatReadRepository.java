package com.telugutunes.api.repository;

import com.telugutunes.api.domain.ChatReadDocument;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface ChatReadRepository extends MongoRepository<ChatReadDocument, String> {}
