package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.AssistantRequest;
import com.telugutunes.api.api.dto.AssistantResponse;
import com.telugutunes.api.api.dto.MetadataSuggestionRequest;
import com.telugutunes.api.api.dto.MetadataSuggestionResponse;
import com.telugutunes.api.service.GeminiAssistantService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/assistant")
public class AssistantController {
  private final GeminiAssistantService assistant;

  public AssistantController(GeminiAssistantService assistant) {
    this.assistant = assistant;
  }

  @PostMapping
  public AssistantResponse suggest(@Valid @RequestBody AssistantRequest request) {
    return assistant.suggest(request.prompt());
  }

  @PostMapping("/metadata")
  public MetadataSuggestionResponse metadata(@Valid @RequestBody MetadataSuggestionRequest request) {
    return assistant.suggestMetadata(request.query());
  }
}
