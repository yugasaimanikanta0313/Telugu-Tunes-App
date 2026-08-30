package com.telugutunes.api.repository;

import com.telugutunes.api.domain.PlaylistDocument;
import java.util.List;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;

public interface PlaylistRepository extends MongoRepository<PlaylistDocument, String> {
  @Query("{'$or': [{'ownerMemberId': ?0}, {'sharedWithMemberIds': ?1}]}")
  List<PlaylistDocument> findByOwnerMemberIdOrSharedWithMemberIdsContains(String ownerMemberId, String memberId);
}
