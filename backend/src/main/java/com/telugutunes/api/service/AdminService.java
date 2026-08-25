package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.AdminMemberResponse;
import com.telugutunes.api.api.dto.UpdateMemberAccessRequest;
import com.telugutunes.api.domain.Member;
import com.telugutunes.api.domain.MemberRole;
import com.telugutunes.api.exception.NotFoundException;
import com.telugutunes.api.repository.MemberRepository;
import java.util.HashSet;
import java.util.Set;
import org.springframework.stereotype.Service;

@Service
public class AdminService {
  private final AuthService auth;
  private final MemberRepository members;

  public AdminService(AuthService auth, MemberRepository members) {
    this.auth = auth;
    this.members = members;
  }

  public java.util.List<AdminMemberResponse> members(String administratorId) {
    auth.requireAdministrator(administratorId);
    return members.findAll().stream()
        .sorted(java.util.Comparator.comparing(Member::displayName, String.CASE_INSENSITIVE_ORDER))
        .map(AdminMemberResponse::from)
        .toList();
  }

  public AdminMemberResponse update(
      String administratorId, String targetMemberId, UpdateMemberAccessRequest request) {
    auth.requireAdministrator(administratorId);
    var target = members.findById(targetMemberId).orElseThrow(() -> new NotFoundException("Member not found."));
    if (administratorId.equals(targetMemberId) && Boolean.FALSE.equals(request.active())) {
      throw new IllegalArgumentException("You cannot disable your own administrator account.");
    }

    var roles = new HashSet<>(target.roles());
    if (!roles.contains(MemberRole.OWNER) && request.admin() != null) {
      if (request.admin()) {
        roles.add(MemberRole.ADMIN);
      } else {
        roles.remove(MemberRole.ADMIN);
      }
    }
    if (roles.isEmpty()) roles.add(MemberRole.MEMBER);
    var updated =
        members.save(
            new Member(
                target.id(),
                target.displayName(),
                target.email(),
                target.passwordHash(),
                Set.copyOf(roles),
                request.active() == null ? target.active() : request.active(),
                target.createdAt()));
    return AdminMemberResponse.from(updated);
  }
}
