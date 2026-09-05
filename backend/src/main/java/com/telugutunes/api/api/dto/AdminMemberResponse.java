package com.telugutunes.api.api.dto;

import com.telugutunes.api.domain.Member;
import com.telugutunes.api.domain.MemberRole;
import java.time.Instant;

public record AdminMemberResponse(
    String id,
    String displayName,
    String email,
    boolean active,
    boolean admin,
    boolean owner,
    boolean online,
    Instant lastSeenAt,
    long listeningSeconds) {
  public static AdminMemberResponse from(
      Member member, boolean online, Instant lastSeenAt, long listeningSeconds) {
    var roles = member.roles();
    return new AdminMemberResponse(
        member.id(),
        member.displayName(),
        member.email(),
        member.active(),
        roles.contains(MemberRole.ADMIN) || roles.contains(MemberRole.OWNER),
        roles.contains(MemberRole.OWNER),
        online,
        lastSeenAt,
        listeningSeconds);
  }
}
