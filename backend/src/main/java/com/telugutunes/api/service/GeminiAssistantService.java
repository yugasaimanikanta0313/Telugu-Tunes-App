package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.AssistantResponse;
import com.telugutunes.api.api.dto.MetadataSuggestionResponse;
import com.telugutunes.api.config.AppProperties;
import java.time.Year;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/** Gemini is advisory only: every generated field stays editable before upload. */
@Service
public class GeminiAssistantService {
  private static final Logger log = LoggerFactory.getLogger(GeminiAssistantService.class);
  private final AppProperties properties;
  private final YouTubeMetadataService youtube;
  private final ItunesMetadataService itunes;
  private final RestClient client;
  private final RestClient groqClient;
  private final ObjectMapper mapper = new ObjectMapper();

  public GeminiAssistantService(
      AppProperties properties, YouTubeMetadataService youtube, ItunesMetadataService itunes) {
    this.properties = properties;
    this.youtube = youtube;
    this.itunes = itunes;
    this.client = RestClient.builder().baseUrl("https://generativelanguage.googleapis.com").build();
    this.groqClient = RestClient.builder().baseUrl("https://api.groq.com/openai/v1").build();
  }

  public AssistantResponse suggest(String userPrompt) {
    if (!geminiConfigured()) return new AssistantResponse("Tune AI is not configured yet.", false);
    try {
      return new AssistantResponse(
          generate(
              "You are Tune AI for a private Telugu music library. Give one concise, safe music "
                  + "suggestion. Do not invent library tracks. User request: "
                  + userPrompt.trim()),
          true);
    } catch (RuntimeException exception) {
      log.warn("Gemini assistant request failed: {}", exception.getMessage());
      return new AssistantResponse("Tune AI is temporarily unavailable. Try again in a moment.", false);
    }
  }

  public MetadataSuggestionResponse suggestMetadata(String query) {
    var fallback = fallback(query, "Verify every detail before saving.");
    var video = youtube.find(query).orElse(null);
    var appleQuery = video == null ? query : video.title();
    var apple = itunes.find(appleQuery).orElse(null);
    var sourced = mergeSources(fallback, video, apple);
    if (!geminiConfigured()) {
      return groqMetadataOrSource(query, video, apple, sourced, "Gemini is not configured.");
    }
    try {
      return generatedMetadata(
          generateGeminiJson(metadataPrompt(query, video, apple)),
          sourced,
          sourceName(video, apple) + " + Gemini",
          "Suggestions are editable. Verify credits before saving.");
    } catch (Exception exception) {
      log.warn("Gemini metadata enrichment failed: {}", exception.getMessage());
      return groqMetadataOrSource(query, video, apple, sourced, providerFailure("Gemini", exception));
    }
  }

  private MetadataSuggestionResponse groqMetadataOrSource(
      String query,
      YouTubeMetadataService.VideoMetadata video,
      ItunesMetadataService.TrackMetadata apple,
      MetadataSuggestionResponse sourced,
      String geminiFailure) {
    var groqFailure = "Groq Qwen is not configured.";
    if (groqConfigured()) {
      try {
        return generatedMetadata(
            generateGroqJson(metadataPrompt(query, video, apple)),
            sourced,
            sourceName(video, apple) + " + Groq Qwen",
            "Qwen suggestions are editable. Verify credits before saving.");
      } catch (Exception exception) {
        log.warn("Groq Qwen metadata enrichment failed: {}", exception.getMessage());
        groqFailure = providerFailure("Groq Qwen", exception);
      }
    }
    return video == null && apple == null
        ? fallback(
            query,
            youtube.isConfigured()
                ? "No matching song metadata was found. Enter details manually."
                : "YouTube lookup is not configured. Enter details manually.")
        : new MetadataSuggestionResponse(
            "",
            sourced.artist(),
            sourced.album(),
            sourced.singers(),
            sourced.musicDirector(),
            sourced.genre(),
            sourced.year(),
            sourced.color(),
            sourced.thumbnailUrl(),
            sourced.sourceUrl(),
            sourceName(video, apple),
            false,
            movieNotice(sourced.album(),
                "Catalog details were found. " + geminiFailure + " " + groqFailure
                    + " Review the credits or try again."));
  }

  /** Returns a safe, actionable provider status without including request data or credentials. */
  private String providerFailure(String provider, Exception exception) {
    if (exception instanceof RestClientResponseException responseException) {
      return provider + " returned HTTP " + responseException.getStatusCode().value() + ".";
    }
    return provider + " could not be reached.";
  }

  private MetadataSuggestionResponse generatedMetadata(
      String json, MetadataSuggestionResponse sourced, String source, String notice) throws Exception {
      JsonNode node = mapper.readTree(removeCodeFence(json));
      var artist = text(node, "artist", sourced.artist());
      var album = text(node, "album", sourced.album());
      var singers = text(node, "singers", sourced.singers());
      var musicDirector = text(node, "musicDirector", sourced.musicDirector());
      var genre = text(node, "genre", sourced.genre());
      var year = node.path("year").asInt(0);
      if (year < 0 || year > Year.now().getValue() + 1) year = sourced.year();
      var color = text(node, "color", sourced.color()).replace("#", "").toUpperCase();
      if (!color.matches("[0-9A-F]{6}")) color = "7C4DFF";
      return new MetadataSuggestionResponse(
          "", artist, album, singers, musicDirector, genre, year, color,
          sourced.thumbnailUrl(), sourced.sourceUrl(), source, true, movieNotice(album, notice));
  }

  private String metadataPrompt(
      String query,
      YouTubeMetadataService.VideoMetadata video,
      ItunesMetadataService.TrackMetadata apple) {
    var youtubeSource =
        video == null
            ? "Song filename or title: \"" + query.trim() + "\""
            : "YouTube source (treat it as the primary evidence):\n"
                + "title: \"" + clip(video.title(), 300) + "\"\n"
                + "channel: \"" + clip(video.channelTitle(), 160) + "\"\n"
                + "description: \"" + clip(video.description(), 1200) + "\"\n"
                + "published year: " + video.year();
    var appleSource = apple == null ? "" : "\niTunes catalog match (use for album and genre when it fits):\n"
        + "song: \"" + clip(apple.title(), 200) + "\"\n"
        + "artist: \"" + clip(apple.artist(), 160) + "\"\n"
        + "album: \"" + clip(apple.collection(), 200) + "\"\n"
        + "genre: \"" + clip(apple.genre(), 100) + "\"";
    return "Return ONLY a compact JSON object with artist, album, singers, musicDirector, "
        + "genre, year, color. Never return a title: the member enters and owns the song title. "
        + "Resolve Telugu song metadata from the following source. Use empty strings for unknown "
        + "credits and 0 for an unknown year. Do not invent singers, composers, or album/movie. "
        + "Infer genre from the song's likely musical mood and style when the evidence is sufficient; "
        + "use a short useful label such as Romantic, Melodic, Devotional, Folk, Dance, Sad, or Unknown. "
        + "Artist is the primary performing artist or official channel only when clearly known. "
        + youtubeSource + appleSource;
  }

  private boolean geminiConfigured() {
    return properties.getGemini().getApiKey() != null && !properties.getGemini().getApiKey().isBlank();
  }

  private boolean groqConfigured() {
    return properties.getGroq().getApiKey() != null && !properties.getGroq().getApiKey().isBlank();
  }

  private String generate(String prompt) {
    return generateGemini(prompt, false);
  }

  /** Metadata needs machine-readable fields, not a conversational answer. */
  private String generateGeminiJson(String prompt) {
    return generateGemini(prompt, true);
  }

  private String generateGemini(String prompt, boolean jsonResponse) {
    Map<String, Object> request = new LinkedHashMap<>();
    request.put("contents", List.of(Map.of("parts", List.of(Map.of("text", prompt)))));
    if (jsonResponse) {
      request.put("generationConfig", Map.of("responseMimeType", "application/json"));
    }
    Map<?, ?> response =
        client
            .post()
            .uri(
                builder ->
                    builder
                        .path("/v1beta/models/{model}:generateContent")
                        .build(properties.getGemini().getModel()))
            .header("x-goog-api-key", properties.getGemini().getApiKey())
            .contentType(MediaType.APPLICATION_JSON)
            .body(request)
            .retrieve()
            .body(Map.class);
    var text = extractText(response);
    if (text.isBlank()) throw new IllegalStateException("Gemini returned no readable text.");
    return text;
  }

  /** Uses Groq's OpenAI-compatible chat endpoint, with JSON mode for predictable metadata. */
  private String generateGroqJson(String prompt) {
    Map<String, Object> request = new LinkedHashMap<>();
    request.put("model", properties.getGroq().getModel());
    request.put("messages", List.of(Map.of("role", "user", "content", prompt)));
    request.put("response_format", Map.of("type", "json_object"));
    request.put("temperature", 0.1);
    Map<?, ?> response = groqClient
        .post()
        .uri("/chat/completions")
        .header("Authorization", "Bearer " + properties.getGroq().getApiKey())
        .contentType(MediaType.APPLICATION_JSON)
        .body(request)
        .retrieve()
        .body(Map.class);
    var text = extractGroqText(response);
    if (text.isBlank()) throw new IllegalStateException("Groq returned no readable text.");
    return text;
  }

  private String extractGroqText(Map<?, ?> response) {
    if (response == null || !(response.get("choices") instanceof Iterable<?> choices)) return "";
    for (var choiceValue : choices) {
      if (!(choiceValue instanceof Map<?, ?> choice)
          || !(choice.get("message") instanceof Map<?, ?> message)) continue;
      var content = message.get("content");
      if (content != null && !content.toString().isBlank()) return content.toString();
    }
    return "";
  }

  private String extractText(Map<?, ?> response) {
    if (response == null || !(response.get("candidates") instanceof Iterable<?> candidates)) return "";
    for (var candidateValue : candidates) {
      if (!(candidateValue instanceof Map<?, ?> candidate)
          || !(candidate.get("content") instanceof Map<?, ?> content)
          || !(content.get("parts") instanceof Iterable<?> parts)) continue;
      for (var partValue : parts) {
        if (partValue instanceof Map<?, ?> part && part.get("text") != null) {
          return part.get("text").toString();
        }
      }
    }
    return "";
  }

  private MetadataSuggestionResponse fallback(String query, String notice) {
    return new MetadataSuggestionResponse(
        "",
        "",
        "",
        "",
        "",
        "",
        0,
        "7C4DFF",
        "",
        "",
        "Manual",
        false,
        movieNotice("", notice));
  }

  private MetadataSuggestionResponse fromYouTube(YouTubeMetadataService.VideoMetadata video) {
    var description = video.description();
    var album = descriptionCredit(description, "movie", "film", "album");
    var singers = descriptionCredit(description, "singers", "singer", "vocals", "vocalist");
    var musicDirector = descriptionCredit(
        description, "music director", "music by", "composer", "music");
    return new MetadataSuggestionResponse(
        "",
        video.channelTitle(),
        album,
        singers,
        musicDirector,
        "",
        video.year(),
        "7C4DFF",
        video.thumbnailUrl(),
        video.sourceUrl(),
        "YouTube",
        false,
        "YouTube details were found. Your song title is kept unchanged; Gemini can enrich the remaining credits.");
  }

  private MetadataSuggestionResponse mergeSources(
      MetadataSuggestionResponse fallback,
      YouTubeMetadataService.VideoMetadata video,
      ItunesMetadataService.TrackMetadata apple) {
    var youtubeDetails = video == null ? fallback : fromYouTube(video);
    if (apple == null) return youtubeDetails;
    return new MetadataSuggestionResponse(
        "",
        choose(apple.artist(), youtubeDetails.artist()),
        choose(youtubeDetails.album(), apple.collection()),
        youtubeDetails.singers(),
        youtubeDetails.musicDirector(),
        choose(youtubeDetails.genre(), apple.genre()),
        youtubeDetails.year(),
        youtubeDetails.color(),
        choose(youtubeDetails.thumbnailUrl(), apple.artworkUrl()),
        choose(youtubeDetails.sourceUrl(), apple.sourceUrl()),
        sourceName(video, apple),
        false,
        movieNotice(choose(youtubeDetails.album(), apple.collection()),
            "Catalog details found. Gemini can enrich any missing credits."));
  }

  private String sourceName(
      YouTubeMetadataService.VideoMetadata video, ItunesMetadataService.TrackMetadata apple) {
    if (video != null && apple != null) return "YouTube + iTunes";
    if (apple != null) return "iTunes";
    return video == null ? "Manual" : "YouTube";
  }

  private String choose(String first, String second) {
    return first == null || first.isBlank() ? (second == null ? "" : second) : first;
  }

  /** Many official Telugu uploads include credits as description lines such as "Singers: ...". */
  private String descriptionCredit(String description, String... labels) {
    if (description == null || description.isBlank()) return "";
    for (var label : labels) {
      var pattern = Pattern.compile(
          "(?im)^\\s*" + Pattern.quote(label) + "\\s*[:\\-]\\s*(.+?)\\s*$");
      var match = pattern.matcher(description);
      if (match.find()) return clip(match.group(1).trim(), 180);
    }
    return "";
  }

  private String movieNotice(String album, String notice) {
    return album == null || album.isBlank()
        ? notice + " Movie name could not be identified; enter it before uploading if this is a film song."
        : notice;
  }

  private String clip(String value, int limit) {
    if (value == null) return "";
    return value.length() <= limit ? value : value.substring(0, limit);
  }

  private String removeCodeFence(String text) {
    return text.replaceFirst("^```(?:json)?\\s*", "").replaceFirst("\\s*```$", "").trim();
  }

  private String text(JsonNode node, String name, String fallback) {
    var value = node.path(name).asText("").trim();
    return value.isBlank() ? fallback : value;
  }
}
