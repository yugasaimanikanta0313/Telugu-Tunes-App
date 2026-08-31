import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class TeluguTunesColors {
  static const background = Color(0xFF110A1D);
  static const surface = Color(0xFF21152F);
  static const surfaceHigh = Color(0xFF2B1C3D);
  static const primary = Color(0xFFA263E7);
  static const lavender = Color(0xFFD5B2FF);
  static const text = Color(0xFFF8EFFF);
  static const textMuted = Color(0xFFBCA6CE);
  static const border = Color(0x335F3B7B);
}

ThemeData teluguTunesTheme() {
  const scheme = ColorScheme.dark(
    primary: TeluguTunesColors.primary,
    onPrimary: Color(0xFF1C082F),
    primaryContainer: Color(0xFF4A236F),
    onPrimaryContainer: TeluguTunesColors.text,
    secondary: TeluguTunesColors.lavender,
    onSecondary: Color(0xFF241034),
    surface: TeluguTunesColors.surface,
    onSurface: TeluguTunesColors.text,
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
  );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(22),
    side: const BorderSide(color: TeluguTunesColors.border),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: TeluguTunesColors.background,
    canvasColor: TeluguTunesColors.background,
    dividerColor: TeluguTunesColors.border,
    cardTheme: CardThemeData(
      color: TeluguTunesColors.surface.withValues(alpha: .92),
      elevation: 0,
      shape: rounded,
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: TeluguTunesColors.surfaceHigh,
      shape: rounded,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: TeluguTunesColors.surfaceHigh,
      modalBackgroundColor: TeluguTunesColors.surfaceHigh,
      showDragHandle: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: const Color(0xFF190F24),
      indicatorColor: TeluguTunesColors.primary.withValues(alpha: .26),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color(0xFF190F24),
      indicatorColor: Color(0x554E2873),
      minWidth: 82,
      groupAlignment: -.1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xEE110A1D),
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: TeluguTunesColors.text,
        fontSize: 23,
        fontWeight: FontWeight.w800,
      ),
    ),
    textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: TeluguTunesColors.text,
          displayColor: TeluguTunesColors.text,
        ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TeluguTunesColors.surface.withValues(alpha: .88),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: TeluguTunesColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: TeluguTunesColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: TeluguTunesColors.lavender),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}

class MusicalAurora extends StatefulWidget {
  const MusicalAurora({
    super.key,
    required this.child,
    this.notes = true,
    this.active = true,
    this.noteCount = 4,
  });

  final Widget child;
  final bool notes;
  final bool active;
  final int noteCount;

  @override
  State<MusicalAurora> createState() => _MusicalAuroraState();
}

class _MusicalAuroraState extends State<MusicalAurora>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) || !widget.active) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant MusicalAurora oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !MediaQuery.disableAnimationsOf(context)) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: TeluguTunesColors.background),
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => CustomPaint(
                painter: _AuroraPainter(
                  progress: _controller.value,
                  showNotes: widget.notes,
                  noteCount: widget.noteCount,
                ),
              ),
            ),
          ),
          widget.child,
        ],
      );
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter({
    required this.progress,
    required this.showNotes,
    required this.noteCount,
  });

  final double progress;
  final bool showNotes;
  final int noteCount;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = progress * math.pi * 2;
    void glow(Offset center, double radius, Color color) {
      final paint = Paint()
        ..shader = RadialGradient(colors: [
          color.withValues(alpha: .20),
          color.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    glow(
      Offset(size.width * (.18 + .05 * math.sin(phase)),
          size.height * (.16 + .04 * math.cos(phase))),
      size.shortestSide * .48,
      TeluguTunesColors.primary,
    );
    glow(
      Offset(size.width * (.82 + .04 * math.cos(phase)),
          size.height * (.72 + .05 * math.sin(phase))),
      size.shortestSide * .42,
      const Color(0xFF4965E8),
    );
    if (!showNotes || size.width < 300) return;
    const glyphs = ['♪', '♫', '♬', '♩'];
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var index = 0; index < noteCount; index++) {
      final lane = (index + 1) / (noteCount + 1);
      final drift = (progress + index * .21) % 1;
      textPainter.text = TextSpan(
        text: glyphs[index % glyphs.length],
        style: TextStyle(
          color: TeluguTunesColors.lavender
              .withValues(alpha: .055 + (index % 4) * .012),
          fontSize: 20 + (index % 4) * 4,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size.width * lane + math.sin(phase + index) * 18,
            size.height * (1.05 - drift * 1.2)),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.showNotes != showNotes ||
      oldDelegate.noteCount != noteCount;
}

class FloatingArtwork extends StatefulWidget {
  const FloatingArtwork({
    super.key,
    required this.child,
    required this.active,
  });

  final Widget child;
  final bool active;

  @override
  State<FloatingArtwork> createState() => _FloatingArtworkState();
}

class _FloatingArtworkState extends State<FloatingArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6500),
    );
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant FloatingArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !MediaQuery.disableAnimationsOf(context)) {
      _controller.repeat(reverse: true);
    } else {
      _controller.animateBack(0, duration: const Duration(milliseconds: 280));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (_, child) {
            final value = Curves.easeInOut.transform(_controller.value);
            return Transform.translate(
              offset: Offset(0, -7 * value),
              child: Transform.rotate(
                angle: (value - .5) * math.pi / 90,
                child: child,
              ),
            );
          },
        ),
      );
}

class PlaybackArtworkStage extends StatefulWidget {
  const PlaybackArtworkStage({
    super.key,
    required this.size,
    required this.active,
    required this.child,
  });

  final double size;
  final bool active;
  final Widget child;

  @override
  State<PlaybackArtworkStage> createState() => _PlaybackArtworkStageState();
}

class _PlaybackArtworkStageState extends State<PlaybackArtworkStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbit;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
    if (widget.active) _orbit.repeat();
  }

  @override
  void didUpdateWidget(covariant PlaybackArtworkStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !MediaQuery.disableAnimationsOf(context)) {
      _orbit.repeat();
    } else {
      _orbit.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _orbit.stop();
  }

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: widget.size + 34,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _orbit,
                builder: (_, __) => Transform.rotate(
                  angle: _orbit.value * math.pi * 2,
                  child: CustomPaint(
                    size: Size.square(widget.size + 28),
                    painter: const _OrbitPainter(),
                  ),
                ),
              ),
            ),
            FloatingArtwork(active: widget.active, child: widget.child),
          ],
        ),
      );
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = const SweepGradient(
        colors: [
          Colors.transparent,
          TeluguTunesColors.lavender,
          Colors.transparent,
          TeluguTunesColors.primary,
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(3), const Radius.circular(46)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PlaybackEqualizer extends StatefulWidget {
  const PlaybackEqualizer({super.key, required this.active});

  final bool active;

  @override
  State<PlaybackEqualizer> createState() => _PlaybackEqualizerState();
}

class _PlaybackEqualizerState extends State<PlaybackEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant PlaybackEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !MediaQuery.disableAnimationsOf(context)) {
      _controller.repeat(reverse: true);
    } else {
      _controller.animateBack(0, duration: const Duration(milliseconds: 180));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: widget.active ? 'Music is playing' : 'Music is paused',
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => SizedBox(
              width: 92,
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(9, (index) {
                  final wave = (math.sin(
                              (_controller.value * 2 + index * .28) * math.pi) +
                          1) /
                      2;
                  return Container(
                    width: 5,
                    height: widget.active ? 6 + wave * 18 : 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          TeluguTunesColors.primary,
                          TeluguTunesColors.lavender,
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      );
}
