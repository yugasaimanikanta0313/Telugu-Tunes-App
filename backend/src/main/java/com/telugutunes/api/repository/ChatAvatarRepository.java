package com.telugutunes.api.repository;

import com.telugutunes.api.domain.ChatAvatarDocument;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface ChatAvatarRepository extends MongoRepository<ChatAvatarDocument, String> {}
