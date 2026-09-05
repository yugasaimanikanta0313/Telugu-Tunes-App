import 'package:flutter/material.dart';

class ServerWakeGate extends StatelessWidget {
  const ServerWakeGate({
    super.key,
    required this.apiBaseUrl,
    required this.child,
  });

  final String apiBaseUrl;
  final Widget child;

  @override
  @override
  Widget build(BuildContext context) {
    // Do not block the whole app on a health probe. Individual screens keep
    // their existing retry/error states while the service reconnects.
    return child;
  }
}
