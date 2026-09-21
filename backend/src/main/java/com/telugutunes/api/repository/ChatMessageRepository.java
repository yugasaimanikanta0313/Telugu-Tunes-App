package com.telugutunes.api.repository;

import com.telugutunes.api.domain.ChatMessageDocument;
import java.util.List;
import java.util.Optional;
import java.time.Instant;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface ChatMessageRepository extends MongoRepository<ChatMessageDocument, String> {
  List<ChatMessageDocument> findTop100ByConversationIdAndCreatedAtAfterOrderByCreatedAtDesc(
      String conversationId, Instant cutoff);
  Optional<ChatMessageDocument> findTopByConversationIdAndCreatedAtAfterOrderByCreatedAtDesc(
      String conversationId, Instant cutoff);
  long countByConversationIdAndSenderIdAndCreatedAtAfter(
      String conversationId, String senderId, Instant since);
  List<ChatMessageDocument> findByCreatedAtBefore(Instant cutoff);
  Optional<ChatMessageDocument> findByConversationIdAndSenderIdAndClientId(
      String conversationId, String senderId, String clientId);
  List<ChatMessageDocument> findByMediaId(String mediaId);
  List<ChatMessageDocument> findByConversationIdAndSenderIdAndSeenAtIsNull(
      String conversationId, String senderId);
}
