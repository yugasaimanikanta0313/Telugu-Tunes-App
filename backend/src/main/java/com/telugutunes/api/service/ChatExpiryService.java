package com.telugutunes.api.service;

import com.telugutunes.api.domain.ChatAvatarDocument;
import com.telugutunes.api.repository.ChatAvatarRepository;
import com.telugutunes.api.repository.ChatMessageRepository;
import java.time.Instant;
import java.util.Date;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;
import org.bson.types.ObjectId;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.gridfs.GridFsTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

/** Removes chat history and its GridFS media after the 24-hour visibility window. */
@Service
public class ChatExpiryService {
  private final ChatMessageRepository messages;
  private final ChatAvatarRepository avatars;
  private final GridFsTemplate files;

  public ChatExpiryService(ChatMessageRepository messages,
      ChatAvatarRepository avatars, GridFsTemplate files) {
    this.messages = messages;
    this.avatars = avatars;
    this.files = files;
  }

  @Scheduled(initialDelay = 60_000, fixedDelay = 3_600_000)
  public void clearExpiredChats() {
    Instant cutoff = Instant.now().minusSeconds(86_400);
    var expired = messages.findByCreatedAtBefore(cutoff);
    if (!expired.isEmpty()) messages.deleteAll(expired);

    Set<String> currentAvatars = avatars.findAll().stream()
        .map(ChatAvatarDocument::mediaId).filter(Objects::nonNull)
        .collect(Collectors.toSet());
    var oldUploads = files.find(Query.query(Criteria.where("metadata.ownerId").exists(true)
        .and("uploadDate").lt(Date.from(cutoff))));
    for (var file : oldUploads) {
      String id = file.getObjectId().toHexString();
      if (currentAvatars.contains(id)) continue;
      boolean stillUsed = messages.findByMediaId(id).stream()
          .anyMatch(message -> !message.createdAt().isBefore(cutoff));
      if (!stillUsed) {
        files.delete(Query.query(Criteria.where("_id").is(new ObjectId(id))));
      }
    }
  }
}
