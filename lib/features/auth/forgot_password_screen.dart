import 'package:flutter/material.dart';

import '../../data/services/api_music_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _email;
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _api = SpringBootMusicApiService(BackendConfig.development);
  int _step = 0;
  bool _busy = false;
  String _resetToken = '';

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    setState(() => _busy = true);
    try {
      if (_step == 0) {
        await _api.requestPasswordReset(_email.text.trim());
        if (mounted) setState(() => _step = 1);
      } else if (_step == 1) {
        _resetToken = await _api.verifyPasswordResetOtp(
            _email.text.trim(), _otp.text.trim());
        if (mounted) setState(() => _step = 2);
      } else {
        if (_password.text.length < 8 || _password.text != _confirm.text) {
          throw StateError(
              'Use at least 8 characters and make both passwords match.');
        }
        await _api.resetPassword(
            _email.text.trim(), _resetToken, _password.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Password updated. You can sign in now.')));
          Navigator.pop(context);
        }
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', ''))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Recover your account')),
      body: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                    child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(
                                _step == 0
                                    ? Icons.mark_email_unread_outlined
                                    : _step == 1
                                        ? Icons.password_rounded
                                        : Icons.lock_reset_rounded,
                                size: 54,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(height: 16),
                            Text(
                                _step == 0
                                    ? 'Send verification code'
                                    : _step == 1
                                        ? 'Verify the six-digit code'
                                        : 'Choose a new password',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            Text(
                                _step == 0
                                    ? 'We will email a short-lived code if the account exists.'
                                    : _step == 1
                                        ? 'Check your inbox. The code expires in 10 minutes.'
                                        : 'All existing sessions will be signed out for your protection.',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 24),
                            if (_step == 0)
                              TextField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                      labelText: 'Email address')),
                            if (_step == 1)
                              TextField(
                                  controller: _otp,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  decoration: const InputDecoration(
                                      labelText: 'Verification code')),
                            if (_step == 2) ...[
                              TextField(
                                  controller: _password,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                      labelText: 'New password')),
                              const SizedBox(height: 12),
                              TextField(
                                  controller: _confirm,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Confirm new password')),
                            ],
                            const SizedBox(height: 22),
                            FilledButton(
                                onPressed: _busy ? null : _continue,
                                child: _busy
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : Text(_step == 0
                                        ? 'Email my code'
                                        : _step == 1
                                            ? 'Verify code'
                                            : 'Update password')),
                            if (_step == 1)
                              TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() => _step = 0),
                                  child: const Text('Use a different email')),
                          ],
                        ))),
              ))));
}
