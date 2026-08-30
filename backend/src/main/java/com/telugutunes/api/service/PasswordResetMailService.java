package com.telugutunes.api.service;

import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
public class PasswordResetMailService {
  private final ObjectProvider<JavaMailSender> sender;
  private final String from;

  public PasswordResetMailService(
      ObjectProvider<JavaMailSender> sender,
      @Value("${spring.mail.username:}") String from) {
    this.sender = sender;
    this.from = from;
  }

  public void sendOtp(String email, String otp) {
    if (from == null || from.isBlank()) {
      throw new IllegalStateException("Password recovery email is not configured.");
    }
    var message = new SimpleMailMessage();
    message.setFrom(from);
    message.setTo(email);
    message.setSubject("Your Telugu Tunes password reset code");
    message.setText(
        "Your Telugu Tunes verification code is " + otp
            + ".\n\nIt expires in 10 minutes. If you did not request this, ignore this email.");
    sender.getObject().send(message);
  }
}
