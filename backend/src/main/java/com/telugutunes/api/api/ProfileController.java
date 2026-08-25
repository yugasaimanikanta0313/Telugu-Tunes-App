package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.MemberProfileResponse;
import com.telugutunes.api.config.AuthenticationFilter;
import com.telugutunes.api.service.AuthService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/profile")
public class ProfileController {
  private final AuthService auth;

  public ProfileController(AuthService auth) {
    this.auth = auth;
  }

  @GetMapping
  public MemberProfileResponse profile(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId) {
    return auth.profile(memberId);
  }
}
