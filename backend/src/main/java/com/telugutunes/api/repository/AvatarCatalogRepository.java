package com.telugutunes.api.repository;
import com.telugutunes.api.domain.AvatarCatalogDocument;
import java.util.List;
import org.springframework.data.mongodb.repository.MongoRepository;
public interface AvatarCatalogRepository extends MongoRepository<AvatarCatalogDocument, String> {
  List<AvatarCatalogDocument> findByActiveTrueOrderByCreatedAtDesc();
}
