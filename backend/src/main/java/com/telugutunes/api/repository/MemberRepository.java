package com.telugutunes.api.repository;

import com.telugutunes.api.domain.Member;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface MemberRepository extends MongoRepository<Member, String> {
  Optional<Member> findByEmailIgnoreCase(String email);

  long countByPasswordHashIsNotNull();
}
