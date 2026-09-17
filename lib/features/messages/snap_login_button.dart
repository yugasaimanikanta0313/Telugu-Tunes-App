import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'snap_login_button_stub.dart'
    if (dart.library.html) 'snap_login_button_web.dart' as platform;

/// Client ID and redirect URL come from the Snap Developer Portal.
const snapClientId = String.fromEnvironment('SNAP_CLIENT_ID');
const snapRedirectUri = String.fromEnvironment('SNAP_REDIRECT_URI');

class SnapLoginButton extends StatelessWidget {
  const SnapLoginButton(
      {super.key, required this.onAvatar, required this.onError});

  final ValueChanged<String> onAvatar;
  final ValueChanged<String> onError;

  @override
  Widget build(BuildContext context) {
    if (snapClientId.isEmpty || snapRedirectUri.isEmpty) {
      return FilledButton.icon(
        onPressed: () => onError(
            'Create a Snap Kit app, then set SNAP_CLIENT_ID and SNAP_REDIRECT_URI when running Telugu Tunes.'),
        icon: const Icon(Icons.link),
        label: const Text('Continue with Snapchat'),
      );
    }
    if (!kIsWeb) {
      return FilledButton.icon(
        onPressed: () => onError(
            'Snapchat linking is available in the web app. Android linking needs its registered app redirect.'),
        icon: const Icon(Icons.link),
        label: const Text('Continue with Snapchat'),
      );
    }
    return platform.SnapLoginButtonPlatform(
      clientId: snapClientId,
      redirectUri: snapRedirectUri,
      onAvatar: onAvatar,
      onError: onError,
    );
  }
}
