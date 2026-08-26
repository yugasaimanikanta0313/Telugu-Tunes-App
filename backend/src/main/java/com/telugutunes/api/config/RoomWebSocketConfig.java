package com.telugutunes.api.config;

import com.telugutunes.api.realtime.RoomWebSocketHandler;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

@Configuration
@EnableWebSocket
public class RoomWebSocketConfig implements WebSocketConfigurer {
  private final RoomWebSocketHandler handler;
  private final AppProperties properties;

  public RoomWebSocketConfig(RoomWebSocketHandler handler, AppProperties properties) {
    this.handler = handler;
    this.properties = properties;
  }

  @Override
  public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
    registry
        .addHandler(handler, "/ws/rooms")
        .setAllowedOriginPatterns(properties.getCors().getAllowedOrigins().toArray(String[]::new));
  }
}
