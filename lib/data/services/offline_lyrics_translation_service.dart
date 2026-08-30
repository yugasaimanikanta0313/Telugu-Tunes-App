import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/music_models.dart';

class OfflineLyricsTranslation {
  const OfflineLyricsTranslation({
    required this.plainLyrics,
    required this.syncedLyrics,
    required this.lines,
  });

  final String plainLyrics;
  final String syncedLyrics;
  final List<SyncedLyricLine> lines;

  Map<String, dynamic> toJson() => {
        'plainLyrics': plainLyrics,
        'syncedLyrics': syncedLyrics,
      };
}

class OfflineLyricsTranslationService {
  static const _cachePrefix = 'mlkit_lyrics_translation_v1_';

  bool get isAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<OfflineLyricsTranslation?> cachedTranslation({
    required String trackId,
    required String plainLyrics,
    required String syncedLyrics,
  }) async {
    if (!isAvailable) return null;
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(
      _cacheKey(trackId, plainLyrics, syncedLyrics),
    );
    if (value == null) return null;
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      return _result(
        json['plainLyrics'] as String? ?? '',
        json['syncedLyrics'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<OfflineLyricsTranslation> translate({
    required String trackId,
    required String plainLyrics,
    required String syncedLyrics,
    bool wifiOnly = true,
  }) async {
    if (!isAvailable) {
      throw StateError('Offline translation is available on Android only.');
    }

    final cached = await cachedTranslation(
      trackId: trackId,
      plainLyrics: plainLyrics,
      syncedLyrics: syncedLyrics,
    );
    if (cached != null) return cached;

    final manager = OnDeviceTranslatorModelManager();
    await manager.downloadModel(
      TranslateLanguage.telugu.bcpCode,
      isWifiRequired: wifiOnly,
    );
    await manager.downloadModel(
      TranslateLanguage.english.bcpCode,
      isWifiRequired: wifiOnly,
    );

    final translator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.telugu,
      targetLanguage: TranslateLanguage.english,
    );
    try {
      final source =
          syncedLyrics.trim().isNotEmpty ? syncedLyrics : plainLyrics;
      final timestamp = RegExp(r'^(\[[^\]]+\]\s*)(.*)$');
      final translatedPlain = <String>[];
      final translatedSynced = <String>[];

      for (final rawLine in source.split(RegExp(r'\r?\n'))) {
        final trimmed = rawLine.trim();
        final match = timestamp.firstMatch(trimmed);
        final prefix = match?.group(1) ?? '';
        final text = (match?.group(2) ?? trimmed).trim();
        if (text.isEmpty) {
          translatedPlain.add('');
          translatedSynced.add(prefix);
          continue;
        }
        final translated = (await translator.translateText(text)).trim();
        translatedPlain.add(translated);
        translatedSynced.add('$prefix$translated');
      }

      final result = _result(
        translatedPlain.join('\n'),
        syncedLyrics.trim().isEmpty ? '' : translatedSynced.join('\n'),
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _cacheKey(trackId, plainLyrics, syncedLyrics),
        jsonEncode(result.toJson()),
      );
      return result;
    } finally {
      await translator.close();
    }
  }

  OfflineLyricsTranslation _result(String plain, String synced) =>
      OfflineLyricsTranslation(
        plainLyrics: plain,
        syncedLyrics: synced,
        lines: _parseSyncedLyrics(synced),
      );

  List<SyncedLyricLine> _parseSyncedLyrics(String synced) {
    final expression = RegExp(r'^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$');
    final lines = <SyncedLyricLine>[];
    for (final rawLine in synced.split(RegExp(r'\r?\n'))) {
      final match = expression.firstMatch(rawLine.trim());
      if (match == null) continue;
      final minutes = int.tryParse(match.group(1)!) ?? 0;
      final seconds = double.tryParse(match.group(2)!) ?? 0;
      lines.add(SyncedLyricLine(
        start: Duration(
          milliseconds: ((minutes * 60 + seconds) * 1000).round(),
        ),
        text: match.group(3)?.trim() ?? '',
      ));
    }
    lines.sort((a, b) => a.start.compareTo(b.start));
    return lines;
  }

  String _cacheKey(String trackId, String plain, String synced) {
    var hash = 2166136261;
    for (final unit in '$plain\u0000$synced'.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    return '$_cachePrefix${trackId}_$hash';
  }
}
