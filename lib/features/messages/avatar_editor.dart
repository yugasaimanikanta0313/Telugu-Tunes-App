import 'dart:math' as math;

import 'package:flutter/material.dart';

const defaultAvatarStyle = <String, dynamic>{
  'skin': 'tan',
  'hair': 'short',
  'hairColor': 'black',
  'eyes': 'round',
  'outfit': 'hoodie',
  'outfitColor': 'violet',
  'bottoms': 'jeans',
  'bottomColor': 'blue',
  'pose': 'wave',
  'leftArm': 45,
  'rightArm': -55,
  'leftLeg': -5,
  'rightLeg': 5,
};

class AvatarFigure extends StatelessWidget {
  const AvatarFigure({super.key, this.style, this.compact = false});
  final Map<String, dynamic>? style;
  final bool compact;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _AvatarPainter({...defaultAvatarStyle, ...?style}, compact),
        size: compact ? const Size(48, 48) : const Size(210, 290),
      );
}

class AvatarEditorScreen extends StatefulWidget {
  const AvatarEditorScreen(
      {super.key,
      this.initialStyle,
      required this.onSave,
      required this.onCustomPhoto});
  final Map<String, dynamic>? initialStyle;
  final Future<void> Function(Map<String, dynamic>) onSave;
  final VoidCallback onCustomPhoto;

  @override
  State<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends State<AvatarEditorScreen> {
  late final Map<String, dynamic> style = {
    ...defaultAvatarStyle,
    ...?widget.initialStyle,
  };
  bool saving = false;

  void _set(String key, dynamic value) => setState(() => style[key] = value);

  void _pose(String pose) {
    const presets = <String, List<int>>{
      'stand': [55, 55, -5, 5],
      'wave': [45, -55, -5, 5],
      'dance': [-35, 20, -35, 30],
      'hands-up': [-70, -70, -15, 15],
    };
    final angles = presets[pose]!;
    setState(() {
      style['pose'] = pose;
      style['leftArm'] = angles[0];
      style['rightArm'] = angles[1];
      style['leftLeg'] = angles[2];
      style['rightLeg'] = angles[3];
    });
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await widget.onSave(style);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _choices(String title, String key, List<String> options) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Wrap(spacing: 7, children: [
            for (final option in options)
              ChoiceChip(
                  label: Text(option),
                  selected: style[key] == option,
                  onSelected: (_) => _set(key, option))
          ]),
        ]),
      );

  Widget _angle(String title, String key) => Row(children: [
        SizedBox(width: 92, child: Text(title)),
        Expanded(
            child: Slider(
                value: (style[key] as num).toDouble(),
                min: -90,
                max: 90,
                divisions: 36,
                label: '${style[key]}°',
                onChanged: (value) => _set(key, value.round()))),
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create your avatar'), actions: [
          TextButton(
              onPressed: saving ? null : _save, child: const Text('Save')),
        ]),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          Center(
              child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(28)),
                  child: AvatarFigure(style: style))),
          const SizedBox(height: 16),
          _choices('Skin tone', 'skin', ['light', 'tan', 'brown', 'deep']),
          _choices('Hair', 'hair', ['short', 'curly', 'long', 'bun', 'spiky']),
          _choices('Hair color', 'hairColor',
              ['black', 'brown', 'blonde', 'purple', 'red']),
          _choices('Eyes', 'eyes', ['round', 'sleepy', 'wide', 'wink']),
          _choices('Outfit', 'outfit', ['hoodie', 'jacket', 'dress', 'tee']),
          _choices('Outfit color', 'outfitColor',
              ['violet', 'blue', 'coral', 'green', 'yellow']),
          _choices('Bottoms', 'bottoms', ['jeans', 'shorts', 'skirt']),
          _choices('Bottom color', 'bottomColor',
              ['blue', 'black', 'beige', 'purple']),
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child:
                  Text('Pose', style: Theme.of(context).textTheme.titleMedium)),
          Wrap(spacing: 7, children: [
            for (final pose in ['stand', 'wave', 'dance', 'hands-up'])
              ChoiceChip(
                  label: Text(pose),
                  selected: style['pose'] == pose,
                  onSelected: (_) => _pose(pose))
          ]),
          _angle('Left arm', 'leftArm'),
          _angle('Right arm', 'rightArm'),
          _angle('Left leg', 'leftLeg'),
          _angle('Right leg', 'rightLeg'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: widget.onCustomPhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Use my photo instead')),
          const SizedBox(height: 24),
        ]),
      );
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.style, this.compact);
  final Map<String, dynamic> style;
  final bool compact;

  Color _color(String key, Map<String, Color> colors, String fallback) =>
      colors[style[key] as String?] ?? colors[fallback]!;

  @override
  void paint(Canvas canvas, Size size) {
    if (compact) {
      canvas.save();
      canvas.scale(size.width / 160, size.height / 160);
      canvas.translate(0, -8);
    } else {
      canvas.save();
      canvas.scale(size.width / 160, size.height / 220);
    }
    final skin = _color(
        'skin',
        {
          'light': const Color(0xFFF5C9AA),
          'tan': const Color(0xFFDFA577),
          'brown': const Color(0xFFA76542),
          'deep': const Color(0xFF613927),
        },
        'tan');
    final hair = _color(
        'hairColor',
        {
          'black': const Color(0xFF231B2C),
          'brown': const Color(0xFF5E382A),
          'blonde': const Color(0xFFD3A348),
          'purple': const Color(0xFF7042A9),
          'red': const Color(0xFFB34A3D),
        },
        'black');
    final top = _color(
        'outfitColor',
        {
          'violet': const Color(0xFF7843BE),
          'blue': const Color(0xFF3277C8),
          'coral': const Color(0xFFE46F74),
          'green': const Color(0xFF329573),
          'yellow': const Color(0xFFE1AE39),
        },
        'violet');
    final bottom = _color(
        'bottomColor',
        {
          'blue': const Color(0xFF35557D),
          'black': const Color(0xFF34313F),
          'beige': const Color(0xFFB99A75),
          'purple': const Color(0xFF624B92),
        },
        'blue');
    final outline = Paint()
      ..color = const Color(0xFF35243E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    Paint fill(Color color) => Paint()..color = color;
    void line(Offset a, Offset b, Color color, double width) {
      canvas.drawLine(
          a,
          b,
          Paint()
            ..color = color
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round);
    }

    if (!compact) {
      // Legs bend independently from the hips.
      for (final side in [-1, 1]) {
        final hip = Offset(80 + side * 20, 153);
        final angle =
            ((style[side < 0 ? 'leftLeg' : 'rightLeg'] as num).toDouble()) *
                math.pi /
                180;
        final foot =
            Offset(hip.dx + math.sin(angle) * 51, 201 - angle.abs() * 4);
        line(hip, foot, bottom, style['bottoms'] == 'shorts' ? 13 : 18);
        line(Offset(foot.dx - 8, foot.dy + 3), Offset(foot.dx + 8, foot.dy + 3),
            const Color(0xFF2B2137), 9);
      }
      if (style['bottoms'] == 'skirt') {
        canvas.drawPath(
            Path()
              ..moveTo(58, 146)
              ..lineTo(102, 146)
              ..lineTo(112, 175)
              ..lineTo(48, 175)
              ..close(),
            fill(bottom));
      }
      // Arms follow their own angle sliders.
      for (final side in [-1, 1]) {
        final shoulder = Offset(80 + side * 31, 110);
        final angle =
            ((style[side < 0 ? 'leftArm' : 'rightArm'] as num).toDouble()) *
                math.pi /
                180;
        final hand = Offset(shoulder.dx + side * math.cos(angle) * 43,
            shoulder.dy + math.sin(angle) * 43);
        line(shoulder, hand, top, 16);
        canvas.drawCircle(hand, 8, fill(skin));
      }
      final torso = RRect.fromRectAndRadius(
          const Rect.fromLTWH(49, 100, 62, 59), const Radius.circular(18));
      canvas.drawRRect(torso, fill(top));
      canvas.drawRRect(torso, outline);
      if (style['outfit'] == 'jacket') {
        line(const Offset(80, 104), const Offset(80, 153), Colors.white70, 3);
      } else if (style['outfit'] == 'hoodie') {
        canvas.drawArc(
            const Rect.fromLTWH(62, 99, 36, 20),
            0,
            math.pi,
            false,
            Paint()
              ..color = Colors.white70
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3);
      } else if (style['outfit'] == 'dress') {
        canvas.drawPath(
            Path()
              ..moveTo(56, 138)
              ..lineTo(104, 138)
              ..lineTo(119, 175)
              ..lineTo(41, 175)
              ..close(),
            fill(top));
      }
    }

    // Face and hairstyle remain large enough to read in the inbox.
    canvas.drawOval(const Rect.fromLTWH(43, 33, 74, 76), fill(skin));
    canvas.drawOval(const Rect.fromLTWH(43, 33, 74, 76), outline);
    canvas.drawCircle(const Offset(42, 70), 8, fill(skin));
    canvas.drawCircle(const Offset(118, 70), 8, fill(skin));
    final hairstyle = style['hair'] as String? ?? 'short';
    if (hairstyle == 'long') {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(36, 28, 88, 93), const Radius.circular(27)),
          fill(hair));
      canvas.drawOval(const Rect.fromLTWH(43, 33, 74, 76), fill(skin));
    } else if (hairstyle == 'bun') {
      canvas.drawCircle(const Offset(80, 21), 19, fill(hair));
    }
    if (hairstyle == 'curly') {
      for (var i = 0; i < 7; i++) {
        canvas.drawCircle(
            Offset(49 + i * 10.2, 39 - (i.isEven ? 4 : 0)), 12, fill(hair));
      }
    } else if (hairstyle == 'spiky') {
      final spikes = Path()
        ..moveTo(42, 55)
        ..lineTo(40, 22)
        ..lineTo(55, 35)
        ..lineTo(67, 14)
        ..lineTo(79, 34)
        ..lineTo(97, 16)
        ..lineTo(103, 38)
        ..lineTo(118, 31)
        ..lineTo(116, 56)
        ..close();
      canvas.drawPath(spikes, fill(hair));
    } else {
      canvas.drawArc(
          const Rect.fromLTWH(43, 31, 74, 47),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = hair
            ..style = PaintingStyle.stroke
            ..strokeWidth = 17);
    }
    final eyes = style['eyes'] as String? ?? 'round';
    for (final x in [65.0, 95.0]) {
      if (eyes == 'wink' && x == 95.0 || eyes == 'sleepy') {
        line(
            Offset(x - 5, 70), Offset(x + 5, 70), const Color(0xFF342534), 2.5);
      } else {
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(x, 69),
                width: eyes == 'wide' ? 12 : 8,
                height: eyes == 'wide' ? 14 : 10),
            fill(Colors.white));
        canvas.drawCircle(Offset(x, 70), 3.4, fill(const Color(0xFF302236)));
      }
    }
    canvas.drawArc(
        const Rect.fromLTWH(69, 78, 22, 13),
        0,
        math.pi,
        false,
        Paint()
          ..color = const Color(0xFF80444A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) =>
      oldDelegate.style.toString() != style.toString() ||
      oldDelegate.compact != compact;
}
