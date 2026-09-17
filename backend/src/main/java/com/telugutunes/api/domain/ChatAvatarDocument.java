package com.telugutunes.api.domain;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("chat_avatars")
public record ChatAvatarDocument(@Id String memberId, String mediaId,
    String emoji, AvatarStyle style) {}
