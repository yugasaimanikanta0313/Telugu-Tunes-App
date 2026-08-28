package com.telugutunes.api.repository;

import com.telugutunes.api.domain.FestivalGreetingDocument;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface FestivalGreetingRepository extends MongoRepository<FestivalGreetingDocument, String> {
  Optional<FestivalGreetingDocument> findFirstByDate(LocalDate date);
  List<FestivalGreetingDocument> findAllByOrderByDateAsc();
}
