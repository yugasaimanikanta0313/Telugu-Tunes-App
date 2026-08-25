package com.telugutunes.api.repository;

import com.telugutunes.api.domain.AuthSessionDocument;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface AuthSessionRepository extends MongoRepository<AuthSessionDocument, String> {
  Optional<AuthSessionDocument> findByTokenHash(String tokenHash);
}
