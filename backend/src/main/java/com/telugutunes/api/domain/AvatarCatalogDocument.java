package com.telugutunes.api.domain;
import java.time.Instant;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
@Document("avatar_catalog")
public record AvatarCatalogDocument(@Id String id, String name, String mediaId,
    String previewMediaId, String fileName, boolean active, Instant createdAt) {}
