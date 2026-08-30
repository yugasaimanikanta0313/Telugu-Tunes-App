package com.telugutunes.api.repository;

import com.telugutunes.api.domain.PlaylistInvitationDocument;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface PlaylistInvitationRepository extends MongoRepository<PlaylistInvitationDocument, String> {
  List<PlaylistInvitationDocument> findByInviteeMemberIdAndStatusOrderByCreatedAtDesc(String memberId, String status);
  Optional<PlaylistInvitationDocument> findByPlaylistIdAndInviteeMemberIdAndStatus(
      String playlistId, String inviteeMemberId, String status);
}
