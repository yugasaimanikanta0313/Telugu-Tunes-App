package com.telugutunes.api.repository;
import com.telugutunes.api.domain.HiddenBundledAvatarDocument;
import org.springframework.data.mongodb.repository.MongoRepository;
public interface HiddenBundledAvatarRepository extends MongoRepository<HiddenBundledAvatarDocument, String> {}
