package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.RecommendationVoteRequest;
import com.telugutunes.api.api.dto.RecommendationVoteResponse;
import com.telugutunes.api.config.AuthenticationFilter;
import com.telugutunes.api.service.RecommendationVoteService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/recommendation-votes")
public class RecommendationVotesController {
  private final RecommendationVoteService service;
  public RecommendationVotesController(RecommendationVoteService service) { this.service = service; }

  @PostMapping("/tracks/{trackId}") @ResponseStatus(HttpStatus.NO_CONTENT)
  public void vote(@RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String trackId, @Valid @RequestBody RecommendationVoteRequest request) {
    service.vote(memberId, trackId, request);
  }
  @GetMapping("/admin")
  public List<RecommendationVoteResponse> pending(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId) {
    return service.pending(memberId);
  }
  @PostMapping("/admin/{playlistId}/tracks/{trackId}/approve") @ResponseStatus(HttpStatus.NO_CONTENT)
  public void approve(@RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String playlistId, @PathVariable String trackId) {
    service.review(memberId, playlistId, trackId, true);
  }
  @PostMapping("/admin/{playlistId}/tracks/{trackId}/reject") @ResponseStatus(HttpStatus.NO_CONTENT)
  public void reject(@RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String playlistId, @PathVariable String trackId) {
    service.review(memberId, playlistId, trackId, false);
  }
}
