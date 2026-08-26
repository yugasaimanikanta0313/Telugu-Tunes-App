package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.BackupSnapshot;
import com.telugutunes.api.config.AuthenticationFilter;
import com.telugutunes.api.service.BackupService;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/backup")
public class BackupController {
  private final BackupService backups;

  public BackupController(BackupService backups) {
    this.backups = backups;
  }

  @GetMapping
  public ResponseEntity<BackupSnapshot> export(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String administratorId) {
    return ResponseEntity.ok()
        .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=telugu-tunes-backup.json")
        .body(backups.exportSnapshot(administratorId));
  }

  @PostMapping
  public BackupSnapshot restore(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String administratorId,
      @RequestBody BackupSnapshot snapshot) {
    return backups.restore(administratorId, snapshot);
  }
}
