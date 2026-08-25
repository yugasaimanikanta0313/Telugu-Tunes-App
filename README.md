# Telugu Tunes — private Flutter music client

A polished Flutter Android client for a private Telugu music circle. It contains no audio files, no external artwork, and no copyrighted media metadata: every title, artist, and cover shown in the offline fallback is fictional placeholder content.

## Included in V1

- Material 3 dark interface with phone, tablet, and desktop-width layouts
- Home discovery shelves for Telugu mixes, albums, and movie worlds
- Search with mood shortcuts, library, favorites, private playlists, and offline indicators
- Album/movie detail, animated now-playing view, and persistent mini-player
- Listen-together room with an invite code, listener state, and shared queue
- Email/password sign-in for the private circle; passwords are handled only by the backend
- Real audio playback for uploaded Drive audio, with a responsive mini-player and now-playing screen
- Add music flow with editable Gemini metadata suggestions before device files are uploaded
- Settings and connection-status screen
- Mock Tune AI suggestions with a Gemini-ready backend boundary
- Repository, models, controller, and API service contracts separated from screens

## Project layout

    lib/
      data/        Repository and backend-service boundaries
      domain/      UI-neutral models
      features/    Feature-first screens and shared widgets
      state/       App controller / view state
      test/          Smoke test for the client

## Run it locally

With the Spring Boot backend running locally:

    flutter pub get
    flutter test
    flutter run -d chrome

The client opens a private account screen on its first connection, then calls `http://localhost:8080/api/v1` by default. To force fictional offline data instead:

    flutter run -d chrome --dart-define=USE_MOCK_DATA=true

## Build an APK

For a private, locally installable release:

    flutter build apk --release

The APK will be at build\app\outputs\flutter-apk\app-release.apk. Before sharing beyond test devices, add your own release signing configuration under android.

## Backend handoff

The backend folder contains the Spring Boot API. The client connects to it automatically when it is available and falls back to local fictional metadata only when it is not.

Suggested Spring Boot endpoints:

    POST /api/v1/auth/register
    POST /api/v1/auth/login
    GET  /api/v1/home
    GET  /api/v1/tracks/search?q=
    GET  /api/v1/albums
    GET  /api/v1/playlists
    GET  /api/v1/rooms
    POST /api/v1/imports/audio
    POST /api/v1/imports/reference
    POST /api/v1/assistant
    POST /api/v1/assistant/metadata

Use Spring Boot as the only caller of MongoDB Atlas, Google Drive, and Gemini. The app should receive only scoped data and short-lived audio URLs; no Drive or Gemini keys should be bundled into an APK. For a physical Android device, supply the computer's LAN address:

    flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8080/api/v1

See backend/README.md for Atlas, Drive folder, Gemini, and physical-device setup. Do not put any secret in this Flutter project.
