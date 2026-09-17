package com.telugutunes.api.domain;

/** An original, adjustable full-body chat avatar. */
public record AvatarStyle(String presentation, String skin, String hair, String hairColor,
    String eyes, String outfit, String outfitColor, String bottoms,
    String bottomColor, String pose, int leftArm, int rightArm,
    int leftLeg, int rightLeg, String costume, String accessory,
    String shoes, Integer bodyWidth, Integer headSize, Integer rotation) {
  public AvatarStyle {
    // Existing avatars predate these three controls. MongoDB supplies null
    // for absent fields, so normalize them before returning the record.
    bodyWidth = bodyWidth == null ? 50 : bodyWidth;
    headSize = headSize == null ? 50 : headSize;
    rotation = rotation == null ? 0 : rotation;
  }

  public static final AvatarStyle DEFAULT = new AvatarStyle(
      "neutral", "tan", "short", "black", "round", "hoodie", "violet",
      "jeans", "blue", "wave", 45, -55, -5, 5,
      "everyday", "none", "sneakers", 50, 50, 0);
}
