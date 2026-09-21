package com.telugutunes.api.domain;

import java.time.LocalDate;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("member_details")
public record MemberDetailsDocument(@Id String memberId, LocalDate dateOfBirth, String city) {}
