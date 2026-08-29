package com.telugutunes.api.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.telugutunes.api.api.dto.RecommendedPlaylistPreferenceRequest;
import com.telugutunes.api.domain.RecommendedPlaylistPreferenceDocument;
import com.telugutunes.api.repository.RecommendedPlaylistPreferenceRepository;
import com.telugutunes.api.repository.RecommendedPlaylistRepository;
import java.util.List;
import org.junit.jupiter.api.Test;

class RecommendedPlaylistPreferenceServiceTest {
  @Test
  void savesAValidatedMemberSpecificSchedule() {
    var preferences = mock(RecommendedPlaylistPreferenceRepository.class);
    var playlists = mock(RecommendedPlaylistRepository.class);
    when(playlists.existsById("playlist-1")).thenReturn(true);
    when(preferences.save(any(RecommendedPlaylistPreferenceDocument.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));
    var service = new RecommendedPlaylistPreferenceService(preferences, playlists);

    var saved = service.save("member-1", "playlist-1",
        new RecommendedPlaylistPreferenceRequest(true, List.of(5, 1, 5, 9), "06:00", "10:00"));

    assertThat(saved.playlistId()).isEqualTo("playlist-1");
    assertThat(saved.enabled()).isTrue();
    assertThat(saved.scheduleDays()).containsExactly(1, 5);
    assertThat(saved.scheduleStart()).isEqualTo("06:00");
    assertThat(saved.scheduleEnd()).isEqualTo("10:00");
  }
}
