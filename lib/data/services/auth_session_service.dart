import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/music_models.dart';
import 'api_music_service.dart';

/// Persists only an opaque server session token, never a password or API key.
class AuthSessionService {
  static const _token = 'auth_token';
  static const _memberId = 'auth_member_id';
  static const _name = 'auth_member_name';
  static const _email = 'auth_member_email';
  static const _isAdmin = 'auth_member_admin';

  Future<ApiSession?> restore(BackendConfig baseConfig) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_token);
    final id = prefs.getString(_memberId);
    final name = prefs.getString(_name);
    final email = prefs.getString(_email);
    if (token == null || id == null || name == null || email == null)
      return null;
    return ApiSession(
      config: baseConfig.copyWith(memberId: id, authToken: token),
      member: MemberProfile(
        id: id,
        displayName: name,
        email: email,
        isAdmin: prefs.getBool(_isAdmin) ?? false,
      ),
    );
  }

  Future<void> save(ApiSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_token, session.config.authToken);
    await prefs.setString(_memberId, session.member.id);
    await prefs.setString(_name, session.member.displayName);
    await prefs.setString(_email, session.member.email);
    await prefs.setBool(_isAdmin, session.member.isAdmin);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_token),
      prefs.remove(_memberId),
      prefs.remove(_name),
      prefs.remove(_email),
      prefs.remove(_isAdmin),
    ]);
  }
}
