package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.FestivalGreetingRequest;
import com.telugutunes.api.api.dto.FestivalGreetingResponse;
import com.telugutunes.api.config.AuthenticationFilter;
import com.telugutunes.api.service.FestivalGreetingService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/festival-greetings")
public class FestivalGreetingsController {
  private final FestivalGreetingService service;
  public FestivalGreetingsController(FestivalGreetingService service) { this.service = service; }

  @GetMapping("/today") public ResponseEntity<FestivalGreetingResponse> today() {
    return service.today().map(ResponseEntity::ok).orElseGet(() -> ResponseEntity.noContent().build());
  }
  @GetMapping("/admin") public List<FestivalGreetingResponse> adminList(@RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId) { return service.adminList(memberId); }
  @PostMapping @ResponseStatus(HttpStatus.CREATED)
  public FestivalGreetingResponse create(@RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId, @Valid @RequestBody FestivalGreetingRequest request) { return service.save(memberId, null, request); }
  @PutMapping("/{id}") public FestivalGreetingResponse update(@RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId, @PathVariable String id, @Valid @RequestBody FestivalGreetingRequest request) { return service.save(memberId, id, request); }
  @DeleteMapping("/{id}") @ResponseStatus(HttpStatus.NO_CONTENT)
  public void delete(@RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId, @PathVariable String id) { service.delete(memberId, id); }
}
