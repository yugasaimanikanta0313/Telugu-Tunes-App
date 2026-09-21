package com.telugutunes.api.domain;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
@Document("hidden_bundled_avatars")
public record HiddenBundledAvatarDocument(@Id String presetId) {}
