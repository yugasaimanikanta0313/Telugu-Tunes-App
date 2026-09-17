package com.telugutunes.api.domain;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.bson.Document;
import org.junit.jupiter.api.Test;
import org.springframework.data.mongodb.core.convert.MappingMongoConverter;
import org.springframework.data.mongodb.core.convert.NoOpDbRefResolver;
import org.springframework.data.mongodb.core.mapping.MongoMappingContext;

class AvatarStyleCompatibilityTest {
  @Test
  void readsAvatarsSavedBeforeBodyControlsWereAdded() throws Exception {
    var context = new MongoMappingContext();
    context.afterPropertiesSet();
    var converter = new MappingMongoConverter(NoOpDbRefResolver.INSTANCE, context);
    converter.afterPropertiesSet();

    var oldStyle = Document.parse("""
        {"presentation":"male","skin":"tan","hair":"short",
         "hairColor":"black","eyes":"round","outfit":"hoodie",
         "outfitColor":"violet","bottoms":"jeans","bottomColor":"blue",
         "pose":"wave","leftArm":45,"rightArm":-55,
         "leftLeg":-5,"rightLeg":5}
        """);

    var avatar = converter.read(AvatarStyle.class, oldStyle);
    assertEquals(50, avatar.bodyWidth());
    assertEquals(50, avatar.headSize());
    assertEquals(0, avatar.rotation());

    var savedAvatar = new Document("_id", "member-1")
        .append("mediaId", "")
        .append("emoji", "")
        .append("style", oldStyle)
        .append("snapAvatarUrl", "");
    var chatAvatar = converter.read(ChatAvatarDocument.class, savedAvatar);
    assertEquals(50, chatAvatar.style().bodyWidth());
  }
}
