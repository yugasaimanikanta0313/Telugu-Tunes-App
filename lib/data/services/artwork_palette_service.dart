import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

class ArtworkPaletteService {
  final Map<String, int> _memoryCache = <String, int>{};

  Future<int?> dominantColor(String imageUrl) async {
    if (imageUrl.isEmpty) return null;
    final cached = _memoryCache[imageUrl];
    if (cached != null) return cached;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(imageUrl),
        maximumColorCount: 12,
        size: const Size(160, 160),
      );
      final color = palette.vibrantColor?.color ??
          palette.dominantColor?.color ??
          palette.mutedColor?.color;
      if (color == null) return null;
      _memoryCache[imageUrl] = color.toARGB32();
      if (_memoryCache.length > 80) {
        _memoryCache.remove(_memoryCache.keys.first);
      }
      return color.toARGB32();
    } catch (_) {
      return null;
    }
  }
}
