package com.telugutunes.api.domain;

import java.time.Instant;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("metadata_catalog")
public record MetadataCatalogEntry(
    @Id String id,
    String songName,
    String primaryArtist,
    String album,
    String singers,
    String musicDirector,
    String genre,
    String artworkUrl,
    String normalizedSongName,
    Instant updatedAt) {}
