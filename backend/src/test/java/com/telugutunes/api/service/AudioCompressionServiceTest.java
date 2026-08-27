package com.telugutunes.api.service;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

class AudioCompressionServiceTest {
  @Test
  void compressesOversizedAudioToMp3BelowFiveMegabytes() throws Exception {
    Assumptions.assumeTrue(commandExists("ffmpeg") && commandExists("ffprobe"));
    var sourceBytes = oversizedWave();
    var source = new MockMultipartFile("file", "large-song.wav", "audio/wav", sourceBytes);

    try (var prepared = new AudioCompressionService().prepare(source)) {
      assertThat(prepared.compressed()).isTrue();
      assertThat(prepared.file().getOriginalFilename()).endsWith(".mp3");
      assertThat(prepared.file().getContentType()).isEqualTo("audio/mpeg");
      assertThat(prepared.originalBytes()).isEqualTo(sourceBytes.length);
      assertThat(prepared.storedBytes())
          .isPositive()
          .isLessThanOrEqualTo(AudioCompressionService.MAX_STORED_BYTES);
      assertThat(prepared.file().getSize()).isEqualTo(prepared.storedBytes());
    }
  }

  private boolean commandExists(String command) {
    try {
      return new ProcessBuilder(command, "-version").start().waitFor() == 0;
    } catch (IOException exception) {
      return false;
    } catch (InterruptedException exception) {
      Thread.currentThread().interrupt();
      return false;
    }
  }

  private byte[] oversizedWave() throws IOException {
    var sampleRate = 44_100;
    var channels = 2;
    var bitsPerSample = 16;
    var seconds = 40;
    var dataSize = sampleRate * channels * (bitsPerSample / 8) * seconds;
    var output = new ByteArrayOutputStream(44 + dataSize);
    output.write("RIFF".getBytes());
    writeInt(output, 36 + dataSize);
    output.write("WAVEfmt ".getBytes());
    writeInt(output, 16);
    writeShort(output, 1);
    writeShort(output, channels);
    writeInt(output, sampleRate);
    writeInt(output, sampleRate * channels * (bitsPerSample / 8));
    writeShort(output, channels * (bitsPerSample / 8));
    writeShort(output, bitsPerSample);
    output.write("data".getBytes());
    writeInt(output, dataSize);
    output.write(new byte[dataSize]);
    return output.toByteArray();
  }

  private void writeInt(ByteArrayOutputStream output, int value) {
    output.writeBytes(
        ByteBuffer.allocate(Integer.BYTES)
            .order(ByteOrder.LITTLE_ENDIAN)
            .putInt(value)
            .array());
  }

  private void writeShort(ByteArrayOutputStream output, int value) {
    output.writeBytes(
        ByteBuffer.allocate(Short.BYTES)
            .order(ByteOrder.LITTLE_ENDIAN)
            .putShort((short) value)
            .array());
  }
}
