package com.telugutunes.api.domain;

import java.time.Instant;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("chat_reads")
public record ChatReadDocument(@Id String id, Instant lastReadAt) {}
