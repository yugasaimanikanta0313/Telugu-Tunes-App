package com.telugutunes.api.repository;

import com.telugutunes.api.domain.FavoriteDocument;
import java.util.List;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface FavoriteRepository extends MongoRepository<FavoriteDocument, String> {
  List<FavoriteDocument> findAllByMemberId(String memberId);
}
