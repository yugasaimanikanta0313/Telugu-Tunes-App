package com.telugutunes.api.repository;

import com.telugutunes.api.domain.DailyListeningDocument;
import java.util.List;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface DailyListeningRepository extends MongoRepository<DailyListeningDocument, String> {
  List<DailyListeningDocument> findByMemberIdAndDateGreaterThanEqualOrderByDateAsc(
      String memberId, String date);
}
