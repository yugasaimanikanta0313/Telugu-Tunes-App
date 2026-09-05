package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.AdminMemberResponse;
import com.telugutunes.api.api.dto.UpdateMemberAccessRequest;
import com.telugutunes.api.config.AuthenticationFilter;
import com.telugutunes.api.service.AdminService;
import com.telugutunes.api.service.ListeningStatisticsService;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestParam;

@RestController
@RequestMapping("/api/v1/admin/members")
public class AdminController {
  private final AdminService administration;
  private final ListeningStatisticsService statistics;

  public AdminController(AdminService administration, ListeningStatisticsService statistics) {
    this.administration = administration;
    this.statistics = statistics;
  }

  @GetMapping("/{memberId}/statistics")
  public com.telugutunes.api.api.dto.MemberStatisticsResponse statistics(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String administratorId,
      @PathVariable String memberId,
      @RequestParam(defaultValue = "30") int days) {
    return statistics.statistics(administratorId, memberId, days);
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
