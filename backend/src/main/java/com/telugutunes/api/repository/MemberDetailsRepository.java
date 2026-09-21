package com.telugutunes.api.repository;

import com.telugutunes.api.domain.MemberDetailsDocument;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface MemberDetailsRepository extends MongoRepository<MemberDetailsDocument, String> {}
