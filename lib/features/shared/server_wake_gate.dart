import 'package:flutter/material.dart';

import '../../data/services/backend_availability_service.dart';

class ServerWakeGate extends StatefulWidget {
  const ServerWakeGate({
    super.key,
    required this.apiBaseUrl,
    required this.child,
  });

  final String apiBaseUrl;
  final Widget child;

  @override
  State<ServerWakeGate> createState() => _ServerWakeGateState();
}

class _ServerWakeGateState extends State<ServerWakeGate> {
  bool _ready = false;
  bool _failed = false;
  int _attempt = 1;

  @override
  void initState() {
    super.initState();
    _checkBackend();
  }

  Future<void> _checkBackend() async {
    setState(() {
      _failed = false;
      _attempt = 1;
    });
    final ready = await BackendAvailabilityService(widget.apiBaseUrl)
        .waitUntilReady(onAttempt: (attempt) {
      if (mounted) setState(() => _attempt = attempt);
    });
    if (!mounted) return;
    setState(() {
      _ready = ready;
      _failed = !ready;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _failed
                            ? Icons.cloud_off_rounded
                            : Icons.cloud_sync_rounded,
                        size: 56,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _failed
                            ? 'The server is taking longer than expected'
                            : 'Server is waking up…',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _failed
                            ? 'Check your connection and try again. Your music and account are safe.'
                            : 'The free server may need about a minute after being idle. Telugu Tunes will continue automatically.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (_failed)
                        FilledButton.icon(
                          onPressed: _checkBackend,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        )
                      else ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 14),
                        Text(
                          'Automatic attempt $_attempt',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
