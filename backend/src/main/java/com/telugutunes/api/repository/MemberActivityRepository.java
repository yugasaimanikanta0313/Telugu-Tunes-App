package com.telugutunes.api.repository;

import com.telugutunes.api.domain.MemberActivityDocument;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface MemberActivityRepository
    extends MongoRepository<MemberActivityDocument, String> {}
