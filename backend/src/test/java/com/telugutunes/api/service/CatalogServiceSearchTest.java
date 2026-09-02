package com.telugutunes.api.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.telugutunes.api.domain.LyricsDocument;
import com.telugutunes.api.domain.TrackDocument;
import com.telugutunes.api.repository.AlbumRepository;
import com.telugutunes.api.repository.ListeningRoomRepository;
import com.telugutunes.api.repository.LyricsRepository;
import com.telugutunes.api.repository.MemberRepository;
import com.telugutunes.api.repository.PlaylistRepository;
import com.telugutunes.api.repository.TrackRepository;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;

class CatalogServiceSearchTest {
  @Test
  void findsTeluguLyricsUsingRomanizedEnglishQuery() {
    var tracks = mock(TrackRepository.class);
    var lyrics = mock(LyricsRepository.class);
    var track = new TrackDocument("t1", "Song", "Singer", "Album", "album", "3:00",
        180, "7C4DFF", "Singer", "Director", "Devotional", "", "", "audio", "audio/mpeg",
        "member", Instant.now());
    var lyric = new LyricsDocument("t1", "te", "manual", "శివ శివ", "", "", "", "", 1.0,
        "admin", Instant.now());
    when(tracks.findAll()).thenReturn(List.of(track));
    when(lyrics.findAll()).thenReturn(List.of(lyric));
    var service = new CatalogService(tracks, mock(AlbumRepository.class),
        mock(PlaylistRepository.class), mock(ListeningRoomRepository.class), lyrics,
        mock(MemberRepository.class), mock(AuthService.class), mock(ResilientStorageService.class));

    assertThat(service.search("lyrics:shiva")).extracting(item -> item.id()).containsExactly("t1");
  }
}
