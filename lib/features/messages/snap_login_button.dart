import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'snap_login_button_stub.dart'
    if (dart.library.html) 'snap_login_button_web.dart' as platform;

/// Client ID and redirect URL come from the Snap Developer Portal.
const snapClientId = String.fromEnvironment('SNAP_CLIENT_ID');
const snapRedirectUri = String.fromEnvironment('SNAP_REDIRECT_URI');
const _androidSnapLogin = MethodChannel('telugu_tunes/snap_login');

class SnapLoginButton extends StatelessWidget {
  const SnapLoginButton(
      {super.key, required this.onAvatar, required this.onError});

  final ValueChanged<String> onAvatar;
  final ValueChanged<String> onError;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return FilledButton.icon(
        onPressed: () async {
          try {
            final url = await _androidSnapLogin.invokeMethod<String>('start');
            if (url == null || url.isEmpty) {
              onError('Snapchat did not provide a Bitmoji avatar.');
            } else {
              onAvatar(url);
            }
          } on PlatformException catch (error) {
            onError(error.message ?? 'Snapchat sign-in failed.');
          }
        },
        icon: const Icon(Icons.link),
        label: const Text('Continue with Snapchat'),
      );
    }
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
        onPressed: () => onError('Snapchat linking is not yet available on this platform.'),
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
