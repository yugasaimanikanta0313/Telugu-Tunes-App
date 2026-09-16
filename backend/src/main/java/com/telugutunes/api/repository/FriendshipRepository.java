package com.telugutunes.api.repository;

import com.telugutunes.api.domain.FriendshipDocument;
import java.util.List;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface FriendshipRepository extends MongoRepository<FriendshipDocument, String> {
  List<FriendshipDocument> findByRequesterIdOrRecipientId(String requesterId, String recipientId);
}
