package com.telugutunes.api.repository;

import com.telugutunes.api.domain.ImportJob;
import java.util.List;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface ImportJobRepository extends MongoRepository<ImportJob, String> {
  List<ImportJob> findTop20ByRequestedByMemberIdOrderByCreatedAtDesc(String memberId);
}
