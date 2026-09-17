import 'package:flutter/material.dart';

class SnapLoginButtonPlatform extends StatelessWidget {
  const SnapLoginButtonPlatform(
      {super.key,
      required this.clientId,
      required this.redirectUri,
      required this.onAvatar,
      required this.onError});
  final String clientId;
  final String redirectUri;
  final ValueChanged<String> onAvatar;
  final ValueChanged<String> onError;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
