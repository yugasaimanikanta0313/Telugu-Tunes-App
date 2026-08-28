package com.telugutunes.api.service.lyrics;

import com.telugutunes.api.config.AppProperties;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Locale;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class HttpLyricsifyPageFetcher implements LyricsifyPageFetcher {
  private static final Logger log = LoggerFactory.getLogger(HttpLyricsifyPageFetcher.class);
  private final AppProperties.Lyricsify properties;
  private final HttpClient http;

  @Autowired
  public HttpLyricsifyPageFetcher(AppProperties properties) {
    this(properties, HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(
            properties.getLyrics().getLyricsify().getRequestTimeoutSeconds()))
        .build());
  }

  HttpLyricsifyPageFetcher(AppProperties properties, HttpClient http) {
    this.properties = properties.getLyrics().getLyricsify();
    this.http = http;
  }

  @Override
  public Optional<String> fetch(URI uri) {
    try {
      var request = HttpRequest.newBuilder(uri)
          .timeout(Duration.ofSeconds(properties.getRequestTimeoutSeconds()))
          .header("Accept", "text/html,text/plain;q=0.9")
          .header("User-Agent", "TeluguTunes/1.0 (+https://github.com/yugasaimanikanta0313/Telugu-Tunes-App)")
          .GET().build();
      var response = http.send(request, HttpResponse.BodyHandlers.ofString());
      if (response.statusCode() < 200 || response.statusCode() >= 300) {
        log.info("Lyricsify HTTP miss status={}", response.statusCode());
        return Optional.empty();
      }
      var body = response.body();
      var normalized = body.toLowerCase(Locale.ROOT);
      if (normalized.contains("captcha") || normalized.contains("cf-chl-")
          || normalized.contains("just a moment") || normalized.contains("challenge-platform")) {
        log.info("Lyricsify challenge page detected; optional browser fetcher is not enabled");
        return Optional.empty();
      }
      return body.isBlank() ? Optional.empty() : Optional.of(body);
    } catch (Exception exception) {
      log.info("Lyricsify HTTP fetch failed: {}", exception.getClass().getSimpleName());
      return Optional.empty();
    }
  }
}
