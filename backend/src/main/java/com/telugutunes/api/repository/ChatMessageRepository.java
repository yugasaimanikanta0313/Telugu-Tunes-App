package com.telugutunes.api.repository;

import com.telugutunes.api.domain.ChatMessageDocument;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface ChatMessageRepository extends MongoRepository<ChatMessageDocument, String> {
  List<ChatMessageDocument> findTop100ByConversationIdOrderByCreatedAtDesc(String conversationId);
  Optional<ChatMessageDocument> findByConversationIdAndSenderIdAndClientId(
      String conversationId, String senderId, String clientId);
  List<ChatMessageDocument> findByMediaId(String mediaId);
}
