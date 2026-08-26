FROM maven:3.9.11-eclipse-temurin-21 AS build

WORKDIR /workspace
COPY pom.xml ./
RUN mvn -B -DskipTests dependency:go-offline

COPY src ./src
RUN mvn -B -DskipTests package

FROM eclipse-temurin:21-jre

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --system --uid 10001 appuser
WORKDIR /app
COPY --from=build /workspace/target/telugu-tunes-api-0.1.0.jar app.jar

USER appuser
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75 -Djava.security.egd=file:/dev/urandom"
EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
