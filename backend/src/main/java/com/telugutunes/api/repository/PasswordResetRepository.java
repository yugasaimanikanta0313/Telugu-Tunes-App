package com.telugutunes.api.repository;

import com.telugutunes.api.domain.PasswordResetDocument;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface PasswordResetRepository extends MongoRepository<PasswordResetDocument, String> {}
