package com.telugutunes.api.repository;

import com.telugutunes.api.domain.PlaylistDocument;
import java.util.List;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface PlaylistRepository extends MongoRepository<PlaylistDocument, String> {
  List<PlaylistDocument> findByOwnerMemberIdOrSharedWithMemberIdsContains(String ownerMemberId, String memberId);
}
