package com.telugutunes.api.domain;

/** An original, adjustable full-body chat avatar. */
public record AvatarStyle(String presentation, String skin, String hair, String hairColor,
    String eyes, String outfit, String outfitColor, String bottoms,
    String bottomColor, String pose, int leftArm, int rightArm,
    int leftLeg, int rightLeg) {
  public static final AvatarStyle DEFAULT = new AvatarStyle(
      "neutral", "tan", "short", "black", "round", "hoodie", "violet",
      "jeans", "blue", "wave", 45, -55, -5, 5);
}
