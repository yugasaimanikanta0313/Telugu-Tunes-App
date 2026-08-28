package com.telugutunes.api.service.lyrics;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.telugutunes.api.config.AppProperties;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpResponse;
import org.junit.jupiter.api.Test;

class HttpLyricsifyPageFetcherTest {
  @Test
  void http403IsAGracefulMiss() throws Exception {
    var http = mock(HttpClient.class);
    @SuppressWarnings("unchecked")
    HttpResponse<String> response = mock(HttpResponse.class);
    when(response.statusCode()).thenReturn(403);
    when(http.send(any(), any(HttpResponse.BodyHandler.class))).thenReturn(response);

    var result = new HttpLyricsifyPageFetcher(new AppProperties(), http)
        .fetch(URI.create("https://www.lyricsify.com/search?q=test"));

    assertThat(result).isEmpty();
  }

  @Test
  void timeoutOrIoFailureIsAGracefulMiss() throws Exception {
    var http = mock(HttpClient.class);
    when(http.send(any(), any(HttpResponse.BodyHandler.class)))
        .thenThrow(new IOException("simulated timeout"));

    var result = new HttpLyricsifyPageFetcher(new AppProperties(), http)
        .fetch(URI.create("https://www.lyricsify.com/search?q=test"));

    assertThat(result).isEmpty();
  }
}
