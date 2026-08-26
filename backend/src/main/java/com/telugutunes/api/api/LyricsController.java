package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.LyricsResponse;
import com.telugutunes.api.api.dto.UpdateLyricsRequest;
import com.telugutunes.api.config.AuthenticationFilter;
import com.telugutunes.api.service.LyricsService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/tracks/{trackId}/lyrics")
public class LyricsController {
  private final LyricsService lyrics;

  public LyricsController(LyricsService lyrics) {
    this.lyrics = lyrics;
  }

  @GetMapping
  public LyricsResponse get(@PathVariable String trackId) {
    return lyrics.get(trackId);
  }

  @PostMapping("/import")
  public LyricsResponse refresh(
      @PathVariable String trackId,
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId) {
    return lyrics.refresh(memberId, trackId);
  }

  @PutMapping
  public LyricsResponse update(
      @PathVariable String trackId,
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @Valid @RequestBody UpdateLyricsRequest request) {
    return lyrics.update(memberId, trackId, request);
  }
}
