package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.RecommendedPlaylistRequest;
import com.telugutunes.api.api.dto.RecommendedPlaylistResponse;
import com.telugutunes.api.config.AuthenticationFilter;
import com.telugutunes.api.service.RecommendedPlaylistService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/recommended-playlists")
public class RecommendedPlaylistsController {
  private final RecommendedPlaylistService service;
  public RecommendedPlaylistsController(RecommendedPlaylistService service) { this.service = service; }

  @GetMapping public List<RecommendedPlaylistResponse> list() { return service.publicList(); }
  @GetMapping("/admin") public List<RecommendedPlaylistResponse> adminList(@RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId) { return service.adminList(memberId); }
  @PostMapping @ResponseStatus(HttpStatus.CREATED)
  public RecommendedPlaylistResponse create(@RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId, @Valid @RequestBody RecommendedPlaylistRequest request) { return service.save(memberId, null, request); }
  @PutMapping("/{id}") public RecommendedPlaylistResponse update(@RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId, @PathVariable String id, @Valid @RequestBody RecommendedPlaylistRequest request) { return service.save(memberId, id, request); }
  @DeleteMapping("/{id}") @ResponseStatus(HttpStatus.NO_CONTENT)
  public void delete(@RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId, @PathVariable String id) { service.delete(memberId, id); }
}
