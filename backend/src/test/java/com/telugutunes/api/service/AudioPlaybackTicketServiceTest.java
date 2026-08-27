package com.telugutunes.api.service;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class AudioPlaybackTicketServiceTest {
  @Test
  void ticketOnlyAuthorizesItsTrack() {
    var service = new AudioPlaybackTicketService();
    var issued = service.issue("track-one");

    assertThat(service.isValid(issued.ticket(), "track-one")).isTrue();
    assertThat(service.isValid(issued.ticket(), "track-two")).isFalse();
    assertThat(service.isValid("unknown", "track-one")).isFalse();
  }
}
