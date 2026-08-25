package com.telugutunes.api.api.dto;

import com.telugutunes.api.domain.Member;
import com.telugutunes.api.domain.MemberRole;

public record MemberProfileResponse(String memberId, String displayName, String email, boolean admin) {
  public static MemberProfileResponse from(Member member) {
    var roles = member.roles();
    return new MemberProfileResponse(
        member.id(),
        member.displayName(),
        member.email(),
        roles.contains(MemberRole.OWNER) || roles.contains(MemberRole.ADMIN));
  }
}
