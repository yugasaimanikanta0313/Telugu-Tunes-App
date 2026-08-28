package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.FestivalGreetingRequest;
import com.telugutunes.api.api.dto.FestivalGreetingResponse;
import com.telugutunes.api.domain.FestivalGreetingDocument;
import com.telugutunes.api.exception.NotFoundException;
import com.telugutunes.api.repository.FestivalGreetingRepository;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Service;

@Service
public class FestivalGreetingService {
  private static final String DEFAULT_COLOR = "E15184";
  private static final List<FestivalGreetingResponse> BUILT_INS = List.of(
      builtIn("2026-01-14", "సంక్రాంతి", "సంక్రాంతి శుభాకాంక్షలు! మీ ఇంట ఆనందాల హరివిల్లు విరియాలి."),
      builtIn("2026-03-19", "ఉగాది", "ఉగాది శుభాకాంక్షలు! ఈ నూతన సంవత్సరం సంగీతం, సంతోషం నింపాలి."),
      builtIn("2026-08-28", "రాఖీ పౌర్ణమి", "రాఖీ పౌర్ణమి శుభాకాంక్షలు! అనుబంధాలు ఎల్లప్పుడూ మధురంగా ఉండాలి."),
      builtIn("2026-10-20", "దసరా", "విజయదశమి శుభాకాంక్షలు! మీ ప్రతి ప్రయత్నం విజయవంతం కావాలి."),
      builtIn("2026-11-08", "దీపావళి", "దీపావళి శుభాకాంక్షలు! మీ జీవితంలో వెలుగులు నిండాలి."));

  private final FestivalGreetingRepository repository;
  private final AuthService auth;

  public FestivalGreetingService(FestivalGreetingRepository repository, AuthService auth) {
    this.repository = repository;
    this.auth = auth;
  }

  public Optional<FestivalGreetingResponse> today() {
    return forDate(LocalDate.now(ZoneId.of("Asia/Kolkata")));
  }

  Optional<FestivalGreetingResponse> forDate(LocalDate date) {
    var override = repository.findFirstByDate(date);
    if (override.isPresent()) return override.get().enabled() ? Optional.of(response(override.get())) : Optional.empty();
    return BUILT_INS.stream().filter(item -> item.date().equals(date)).findFirst();
  }

  public List<FestivalGreetingResponse> adminList(String memberId) {
    auth.requireAdministrator(memberId);
    var merged = new LinkedHashMap<LocalDate, FestivalGreetingResponse>();
    BUILT_INS.forEach(item -> merged.put(item.date(), item));
    repository.findAllByOrderByDateAsc().forEach(item -> merged.put(item.date(), response(item)));
    return merged.values().stream().sorted(java.util.Comparator.comparing(FestivalGreetingResponse::date)).toList();
  }

  public FestivalGreetingResponse save(String memberId, String id, FestivalGreetingRequest request) {
    auth.requireAdministrator(memberId);
    var existing = id == null || id.startsWith("built-in-") ? null : repository.findById(id)
        .orElseThrow(() -> new NotFoundException("Festival greeting not found."));
    var sameDate = repository.findFirstByDate(request.date()).orElse(null);
    var targetId = existing != null ? existing.id() : sameDate == null ? null : sameDate.id();
    return response(repository.save(new FestivalGreetingDocument(
        targetId, request.date(), request.festival().trim(), request.greeting().trim(),
        clean(request.artworkUrl()), defaultValue(request.color(), DEFAULT_COLOR),
        request.enabled() == null || request.enabled(), Instant.now())));
  }

  public void delete(String memberId, String id) {
    auth.requireAdministrator(memberId);
    if (!id.startsWith("built-in-")) repository.deleteById(id);
  }

  private FestivalGreetingResponse response(FestivalGreetingDocument item) {
    return new FestivalGreetingResponse(item.id(), item.date(), item.festival(), item.greeting(),
        clean(item.artworkUrl()), defaultValue(item.color(), DEFAULT_COLOR), item.enabled(), false);
  }

  private static FestivalGreetingResponse builtIn(String date, String festival, String greeting) {
    var parsed = LocalDate.parse(date);
    return new FestivalGreetingResponse("built-in-" + date, parsed, festival, greeting, "", DEFAULT_COLOR, true, true);
  }

  private String clean(String value) { return value == null ? "" : value.trim(); }
  private String defaultValue(String value, String fallback) { return value == null || value.isBlank() ? fallback : value.trim(); }
}
