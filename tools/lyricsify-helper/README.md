# Telugu Tunes Admin Helper

This local Chrome extension does not bypass Cloudflare. It only reads an LRC page that the administrator opened normally, requires review, and saves through the existing authenticated Telugu Tunes endpoint.

It can also detect direct audio links on an authorized source page. The administrator must choose one file, review its metadata, and explicitly confirm ownership or permission before upload. The helper rejects protected or indirect players, web-page responses, non-audio files, and files over 50 MB. It does not bypass DRM, access controls, advertisements, or anti-bot systems.

## Install

1. Open `chrome://extensions`.
2. Enable **Developer mode**.
3. Select **Load unpacked**.
4. Choose this `tools/lyricsify-helper` folder.
5. Pin **Telugu Tunes Admin Helper**.

## Use

1. Open the required Lyricsify song page normally.
2. Open the extension and sign in with a Telugu Tunes administrator account.
3. Select **Extract LRC from this page**.
4. Search and select the exact Telugu Tunes track.
5. Review the timestamped lyrics and select **Save to selected song**.

The extension stores the opaque Telugu Tunes session token in Chrome extension storage. It never stores the password. Remove the extension or select **Sign out** to clear the stored token.

## Authorized audio import

1. Open a page containing a direct audio file that you own or are licensed to import.
2. Open the helper and sign in with an administrator account.
3. Select **Detect audio links**, then choose one detected direct file.
4. Review or edit the title, artist, album, singers, music director, genre, and artwork.
5. Confirm the rights statement and select **Review and import audio**.
6. Approve Chrome's one-time request to read the selected audio host.

The selected file is uploaded through Telugu Tunes' existing authenticated import endpoint. Its original source URL is retained with the catalog record.
