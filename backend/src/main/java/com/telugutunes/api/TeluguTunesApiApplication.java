package com.telugutunes.api;

import com.telugutunes.api.config.AppProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;

@SpringBootApplication
@EnableConfigurationProperties(AppProperties.class)
public class TeluguTunesApiApplication {
  public static void main(String[] args) {
    SpringApplication.run(TeluguTunesApiApplication.class, args);
  }
}
