package com.telugutunes.api.service.lyrics;

import static org.assertj.core.api.Assertions.assertThat;

import com.telugutunes.api.config.AppProperties;
import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;

class HttpLyricsifyPageFetcherWiringTest {
  @Test
  void springCanSelectTheProductionConstructor() {
    try (var context = new AnnotationConfigApplicationContext()) {
      context.registerBean(AppProperties.class);
      context.register(HttpLyricsifyPageFetcher.class);
      context.refresh();

      assertThat(context.getBean(HttpLyricsifyPageFetcher.class)).isNotNull();
    }
  }
}
