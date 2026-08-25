package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.AdminMemberResponse;
import com.telugutunes.api.api.dto.UpdateMemberAccessRequest;
import com.telugutunes.api.config.AuthenticationFilter;
import com.telugutunes.api.service.AdminService;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/members")
public class AdminController {
  private final AdminService administration;

  public AdminController(AdminService administration) {
    this.administration = administration;
  }

  @GetMapping
  public List<AdminMemberResponse> members(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String administratorId) {
    return administration.members(administratorId);
  }

  @PatchMapping("/{memberId}")
  public AdminMemberResponse update(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String administratorId,
      @PathVariable String memberId,
      @RequestBody UpdateMemberAccessRequest request) {
    return administration.update(administratorId, memberId, request);
  }
}
