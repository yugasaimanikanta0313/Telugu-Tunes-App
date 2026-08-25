package com.telugutunes.api.repository;

import com.telugutunes.api.domain.ListeningRoomDocument;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface ListeningRoomRepository extends MongoRepository<ListeningRoomDocument, String> {
  Optional<ListeningRoomDocument> findByInviteCode(String inviteCode);
  List<ListeningRoomDocument> findByMemberIdsContainsAndActiveTrue(String memberId);
  List<ListeningRoomDocument> findByPublicRoomTrueAndActiveTrue();
}
