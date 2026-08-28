package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.TrackResponse;
import com.telugutunes.api.config.AuthenticationFilter;
import com.telugutunes.api.service.FavoriteService;
import java.util.List;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/favorites")
public class FavoritesController {
  private final FavoriteService favorites;

  public FavoritesController(FavoriteService favorites) { this.favorites = favorites; }

  @GetMapping
  public List<TrackResponse> list(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId) {
    return favorites.list(memberId);
  }

  @PutMapping("/{trackId}")
  public List<TrackResponse> add(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String trackId) {
    return favorites.add(memberId, trackId);
  }

  @DeleteMapping("/{trackId}")
  public List<TrackResponse> remove(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String trackId) {
    return favorites.remove(memberId, trackId);
  }
}
