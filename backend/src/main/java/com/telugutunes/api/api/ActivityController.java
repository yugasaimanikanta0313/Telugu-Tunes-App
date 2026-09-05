package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.ActivityHeartbeatRequest;
import com.telugutunes.api.config.AuthenticationFilter;
import com.telugutunes.api.service.MemberActivityService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/activity")
public class ActivityController {
  private final MemberActivityService activity;

  public ActivityController(MemberActivityService activity) {
    this.activity = activity;
  }

  @PostMapping("/heartbeat")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  public void heartbeat(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @RequestBody ActivityHeartbeatRequest request) {
    activity.heartbeat(memberId, request);
  }
}
