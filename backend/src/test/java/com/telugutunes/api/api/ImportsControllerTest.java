package com.telugutunes.api.api;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.telugutunes.api.api.dto.ImportResponse;
import com.telugutunes.api.config.AuthenticationFilter;
import com.telugutunes.api.service.ImportService;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.multipart.MultipartFile;

class ImportsControllerTest {
  @Test
  void acceptsLargeFileApprovalAsMultipartFormField() throws Exception {
    ImportService imports = mock(ImportService.class);
    when(imports.importAudio(
            any(), any(MultipartFile.class), any(), any(), any(), any(), any(), any(), any(),
            any(), any(), eq(true)))
        .thenReturn(mock(ImportResponse.class));
    MockMvc mvc = MockMvcBuilders.standaloneSetup(new ImportsController(imports)).build();
    MockMultipartFile file =
        new MockMultipartFile("file", "song.mp3", "audio/mpeg", new byte[] {1, 2, 3});

    mvc.perform(
            multipart("/api/v1/imports/audio")
                .file(file)
                .param("title", "Song")
                .param("allowLargeFile", "true")
                .requestAttr(AuthenticationFilter.MEMBER_ID_ATTRIBUTE, "admin"))
        .andExpect(status().isAccepted());

    verify(imports)
        .importAudio(
            eq("admin"), any(MultipartFile.class), eq("Song"), any(), any(), any(), any(), any(),
            any(), any(), any(), eq(true));
  }
}
