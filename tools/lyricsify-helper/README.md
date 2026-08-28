# Telugu Tunes Lyrics Helper

This local Chrome extension does not bypass Cloudflare. It only reads an LRC page that the administrator opened normally, requires review, and saves through the existing authenticated Telugu Tunes endpoint.

## Install

1. Open `chrome://extensions`.
2. Enable **Developer mode**.
3. Select **Load unpacked**.
4. Choose this `tools/lyricsify-helper` folder.
5. Pin **Telugu Tunes Lyrics Helper**.

## Use

1. Open the required Lyricsify song page normally.
2. Open the extension and sign in with a Telugu Tunes administrator account.
3. Select **Extract LRC from this page**.
4. Search and select the exact Telugu Tunes track.
5. Review the timestamped lyrics and select **Save to selected song**.

The extension stores the opaque Telugu Tunes session token in Chrome extension storage. It never stores the password. Remove the extension or select **Sign out** to clear the stored token.
