# Telugu Tunes API

Spring Boot API for a private, scalable music circle. Member count is not hard-coded: the first password-based account becomes the owner and later accounts receive the member role. It has email/password sign-in with server-stored opaque sessions; keep it on a trusted network until HTTPS and an invitation policy are added.

## What is implemented

- MongoDB documents and repositories for members, tracks, albums, playlists, rooms, and imports
- REST endpoints matching the Flutter client
- Multipart audio upload pipeline with OCI Object Storage (S3-compatible), legacy R2/AWS
  compatibility, and optional Google Drive replication/failover
- Server-side audio proxy endpoint so storage credentials never reach the APK
- Gemini Tune AI endpoint using a server environment variable
- YouTube Data API song lookup (title, channel, year, thumbnail) plus editable Gemini credit enrichment
- Private email/password account registration and login; raw passwords are never stored
- Configured operator email has administrator access; only administrators can edit/delete songs or albums and manage member accounts
- Room creation, joining by invite code, shared queue updates, and owner-or-uploader track deletion
- CORS configuration for Flutter web during development

## Before the first run

1. Install Maven:

       choco install maven -y

2. Copy secrets.yml.example to a private secrets.yml file and fill it locally. The file is ignored by Git and keeps secrets out of shell history.

3. Create a MongoDB Atlas cluster and obtain its complete driver connection URI. The username and password alone are not enough; the URI includes the cluster host and database name.

4. Rotate any database password and Gemini key that were ever pasted into chat or source control, then use newly created values only as environment variables.

5. Enable the Google Drive API in a Google Cloud project. For a personal Google Drive, create a **Web application** OAuth client and download its JSON outside this project. Add this exact authorized redirect URI in Google Cloud: `http://localhost:8080/api/v1/storage/google-drive/callback`.

6. For song details, enable **YouTube Data API v3** in that Google Cloud project, create an API key restricted to that API, and put it under `app.youtube.api-key` in `secrets.yml`. The lookup uses public video metadata and a remote thumbnail URL only; it never downloads YouTube audio or video. A pasted YouTube video URL gives a more reliable match than title-only search.

7. The configured operator email is an administrator by default. Set `APP_ADMIN_EMAILS` to a comma-separated list only if you need to change the administrators for another deployment. After changing an administrator role, sign out and back in to refresh the Flutter app's account badge and settings.

The backend supports OCI Object Storage through its S3-compatible API, plus legacy
Cloudflare R2/AWS environment variables and both Drive authentication modes. It can write each
upload to a primary and backup provider, then automatically try the other replica during playback.
Existing database rows with a plain Drive file ID remain compatible.

## Oracle Object Storage

Use a private Standard-tier bucket and an OCI Customer Secret Key. Never commit or paste the
key. The endpoint is derived automatically from `OCI_NAMESPACE` and `OCI_REGION` and uses OCI's
required path-style S3 access.

Set these environment variables on the backend host:

    APP_STORAGE_PRIMARY=oci
    APP_STORAGE_BACKUP=disabled
    OCI_S3_ENABLED=true
    OCI_NAMESPACE=YOUR_TENANCY_NAMESPACE
    OCI_REGION=ap-hyderabad-1
    OCI_BUCKET=telugu-tunes-media
    OCI_ACCESS_KEY_ID=YOUR_NEW_CUSTOMER_ACCESS_KEY
    OCI_SECRET_ACCESS_KEY=YOUR_NEW_CUSTOMER_SECRET_KEY
    OCI_MAX_BYTES=8000000000

Before changing a running deployment, copy every existing AWS object to OCI while preserving its
full key (for example `audio/uuid-song.mp3`). MongoDB stores those keys, so changing the endpoint
without copying the objects makes existing songs unavailable. New uploads are recorded with the
`oci` provider label; older `s3` and `r2` locator labels remain readable after a same-key migration.

## Deploy to Render with Cloudflare R2

The repository includes a production `Dockerfile` and a root `render.yaml`. Render builds the backend from `backend/` and automatically deploys every commit pushed to the connected branch.

1. In Cloudflare R2, create the private bucket `telugu-tunes-audio` and an object read/write API token scoped only to that bucket.
2. In Render, create a Blueprint from this repository. Supply the secret environment variables requested by the Blueprint: `MONGODB_URI`, `R2_ENDPOINT`, `R2_ACCESS_KEY_ID`, and `R2_SECRET_ACCESS_KEY`. AI-provider keys remain optional.
3. Keep `APP_STORAGE_PRIMARY=r2`. The configured 8 GB software ceiling keeps the application inside the intended small-library budget.
4. Once Render reports healthy, build the APK with the service URL:

       flutter build apk --release --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com/api/v1

The default Render free service can sleep while idle. The Flutter app's startup gate shows “Server is waking up” and retries the health check automatically.

To use Drive as a second replica later, configure persistent Drive credentials, set `GOOGLE_DRIVE_ENABLED=true`, and set `APP_STORAGE_BACKUP=google-drive`. Render's ephemeral filesystem is not suitable for storing a newly generated OAuth refresh-token file, so service-account credentials or an external secret store are preferable there.

## Start locally

In Command Prompt, from the backend folder:

    copy secrets.yml.example secrets.yml
    notepad secrets.yml
    mvn spring-boot:run

The API will listen on http://localhost:8080. Check it with:

    curl http://localhost:8080/actuator/health

For OAuth Drive storage, add these values to `secrets.yml` (use real local paths, but never commit or paste either JSON file):

    app:
      storage:
        provider: google-drive-oauth
        google-drive:
          oauth-client-json: C:/private/telugu-tunes-oauth-client.json
          oauth-token-json: C:/private/telugu-tunes-oauth-token.json
          oauth-redirect-uri: http://localhost:8080/api/v1/storage/google-drive/callback
          folder-id: your-private-drive-folder-id

Start the backend, then open `http://localhost:8080/api/v1/storage/google-drive/connect` in a browser on the backend computer. Sign in with the Drive owner account and approve the narrow file-access permission. The callback page confirms success. On the first upload, the backend creates `Telugu Tunes Uploads (App)` in that owner's Drive and uses it for all media. The optional `folder-id` is used only when the app can already access that folder. The token file is created locally; protect it like a password.

The older service-account option remains available:

    app:
      storage:
        provider: google-drive
        google-drive:
          service-account-json: C:/secure/telugu-tunes-drive-service-account.json
          folder-id: your-folder-id

## API summary

    POST /api/v1/auth/register
    POST /api/v1/auth/login
    GET  /api/v1/home
    GET  /api/v1/tracks/search?q=
    GET  /api/v1/albums
    GET  /api/v1/albums/{id}
    DELETE /api/v1/tracks/{id}              (authenticated owner or uploader)
    GET  /api/v1/playlists                  (authenticated)
    POST /api/v1/playlists                  (authenticated)
    POST /api/v1/playlists/{id}/tracks/{id} (authenticated)
    GET  /api/v1/rooms                      (authenticated)
    POST /api/v1/rooms                      (authenticated)
    POST /api/v1/rooms/join                 (authenticated)
    POST /api/v1/rooms/{id}/queue/{trackId} (authenticated)
    POST /api/v1/imports/audio              (authenticated)
    POST /api/v1/imports/reference          (authenticated)
    GET  /api/v1/audio/{trackId}            (authenticated)
    POST /api/v1/assistant
    POST /api/v1/assistant/metadata

For a physical Android device, the Flutter app must reach your computer by LAN address rather than localhost. Use a temporary development command such as:

    flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8080/api/v1

Replace the LAN address. Use HTTPS and an invitation/approval policy before a non-local deployment.
