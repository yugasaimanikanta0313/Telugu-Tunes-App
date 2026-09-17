import 'dart:math' as math;

import 'package:flutter/material.dart';

const defaultAvatarStyle = <String, dynamic>{
  'presentation': 'neutral',
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
  'costume': 'everyday',
  'accessory': 'none',
  'shoes': 'sneakers',
  'bodyWidth': 50,
  'headSize': 50,
  'rotation': 0,
};

const _collections = <String, List<String>>{
  'Casual': ['everyday', 'street'],
  'Formal': ['business', 'gala'],
  'Comic heroes': ['web-hero', 'tech-hero', 'cape-hero', 'night-guardian'],
  'Halloween': ['spooky', 'witch'],
  'Fantasy': [
    'masked-hero',
    'robot-friend',
    'electric-creature',
    'fire-dragon',
    'alien-shifter'
  ],
};

const _costumeNames = <String, String>{
  'everyday': 'Everyday',
  'street': 'Street style',
  'business': 'Business',
  'gala': 'Gala',
  'web-hero': 'Web hero',
  'tech-hero': 'Tech hero',
  'cape-hero': 'Cape hero',
  'night-guardian': 'Night guardian',
  'spooky': 'Spooky',
  'witch': 'Witch',
  'masked-hero': 'Masked hero',
  'robot-friend': 'Robot friend',
  'electric-creature': 'Electric creature',
  'fire-dragon': 'Fire dragon',
  'alien-shifter': 'Alien shifter',
};

const _costumeStyles = <String, Map<String, dynamic>>{
  'everyday': {
    'outfit': 'hoodie',
    'outfitColor': 'violet',
    'bottoms': 'jeans',
    'bottomColor': 'blue',
    'accessory': 'none'
  },
  'street': {
    'outfit': 'jacket',
    'outfitColor': 'coral',
    'bottoms': 'jeans',
    'bottomColor': 'black',
    'accessory': 'sunglasses'
  },
  'business': {
    'outfit': 'suit',
    'outfitColor': 'blue',
    'bottoms': 'jeans',
    'bottomColor': 'black',
    'shoes': 'formal'
  },
  'gala': {
    'outfit': 'dress',
    'outfitColor': 'violet',
    'bottoms': 'skirt',
    'bottomColor': 'purple',
    'shoes': 'formal'
  },
  'web-hero': {
    'outfit': 'armor',
    'outfitColor': 'coral',
    'bottoms': 'jeans',
    'bottomColor': 'blue',
    'accessory': 'mask'
  },
  'tech-hero': {
    'outfit': 'armor',
    'outfitColor': 'yellow',
    'bottoms': 'jeans',
    'bottomColor': 'black',
    'accessory': 'glasses'
  },
  'cape-hero': {
    'outfit': 'cape',
    'outfitColor': 'blue',
    'bottoms': 'jeans',
    'bottomColor': 'blue',
    'accessory': 'cape'
  },
  'night-guardian': {
    'outfit': 'armor',
    'outfitColor': 'blue',
    'bottoms': 'jeans',
    'bottomColor': 'black',
    'accessory': 'mask'
  },
  'spooky': {
    'outfit': 'robe',
    'outfitColor': 'purple',
    'bottoms': 'jeans',
    'bottomColor': 'black',
    'accessory': 'hat'
  },
  'witch': {
    'outfit': 'robe',
    'outfitColor': 'green',
    'bottoms': 'skirt',
    'bottomColor': 'black',
    'accessory': 'hat'
  },
  'masked-hero': {
    'outfit': 'cape',
    'outfitColor': 'green',
    'bottoms': 'jeans',
    'bottomColor': 'black',
    'accessory': 'mask'
  },
  'robot-friend': {
    'outfit': 'armor',
    'outfitColor': 'blue',
    'bottoms': 'jeans',
    'bottomColor': 'blue',
    'accessory': 'none'
  },
  'electric-creature': {
    'outfit': 'creature',
    'outfitColor': 'yellow',
    'bottoms': 'jeans',
    'bottomColor': 'yellow',
    'accessory': 'hat'
  },
  'fire-dragon': {
    'outfit': 'creature',
    'outfitColor': 'coral',
    'bottoms': 'jeans',
    'bottomColor': 'coral',
    'accessory': 'wings'
  },
  'alien-shifter': {
    'outfit': 'armor',
    'outfitColor': 'green',
    'bottoms': 'jeans',
    'bottomColor': 'black',
    'accessory': 'mask'
  },
};

class AvatarFigure extends StatelessWidget {
  const AvatarFigure({super.key, this.style, this.compact = false});
  final Map<String, dynamic>? style;
  final bool compact;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _Avatar3DPainter({...defaultAvatarStyle, ...?style}, compact),
        size: compact ? const Size(48, 48) : const Size(280, 360),
      );
}

class AvatarEditorScreen extends StatefulWidget {
  const AvatarEditorScreen({
    super.key,
    this.initialStyle,
    required this.onSave,
    required this.onCustomPhoto,
  });
  final Map<String, dynamic>? initialStyle;
  final Future<void> Function(Map<String, dynamic>) onSave;
  final VoidCallback onCustomPhoto;

  @override
  State<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends State<AvatarEditorScreen> {
  late final Map<String, dynamic> style = {
    ...defaultAvatarStyle,
    for (final entry in (widget.initialStyle ?? {}).entries)
      if (entry.value != null) entry.key: entry.value,
  };
  String collection = 'Casual';
  bool saving = false;

  @override
  void initState() {
    super.initState();
    if ((style['bodyWidth'] as num) == 0) style['bodyWidth'] = 50;
    if ((style['headSize'] as num) == 0) style['headSize'] = 50;
    for (final entry in _collections.entries) {
      if (entry.value.contains(style['costume'])) collection = entry.key;
    }
  }

  void _set(String key, dynamic value) => setState(() => style[key] = value);

  void _presentation(String value) => setState(() {
        style['presentation'] = value;
        if (value == 'female') {
          style['hair'] = 'long';
          style['outfit'] = 'dress';
          style['bottoms'] = 'skirt';
        } else if (value == 'male') {
          style['hair'] = 'short';
          style['outfit'] = 'jacket';
          style['bottoms'] = 'jeans';
        }
      });

  void _chooseCostume(String name) => setState(() {
        style['costume'] = name;
        style.addAll(_costumeStyles[name]!);
      });

  void _pose(String pose) {
    const presets = <String, List<int>>{
      'stand': [8, 8, -3, 3],
      'wave': [20, -62, -5, 5],
      'dance': [-38, 28, -35, 30],
      'hands-up': [-65, -65, -15, 15],
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
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save avatar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _choices(String title, String key, List<String> options) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 7),
          Wrap(spacing: 7, runSpacing: 6, children: [
            for (final option in options)
              ChoiceChip(
                label: Text(option),
                selected: style[key] == option,
                onSelected: (_) => _set(key, option),
              ),
          ]),
        ],
      );

  Widget _slider(String title, String key, double min, double max) => Row(
        children: [
          SizedBox(width: 92, child: Text(title)),
          Expanded(
            child: Slider(
              value: (style[key] as num).toDouble().clamp(min, max),
              min: min,
              max: max,
              divisions: (max - min).round(),
              label: '${style[key]}',
              onChanged: (value) => _set(key, value.round()),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Create your avatar'),
          actions: [
            TextButton(
                onPressed: saving ? null : _save, child: const Text('Save')),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onHorizontalDragUpdate: (details) => _set(
                    'rotation',
                    ((style['rotation'] as num).toInt() +
                            details.delta.dx.round() * 2)
                        .clamp(-180, 180)),
                child: Container(
                  width: 320,
                  height: 390,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF153F38),
                        Color(0xFF377C70),
                        Color(0xFFE4F0E9)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        bottom: 24,
                        child: Container(
                          width: 220,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                      AvatarFigure(style: style),
                      const Positioned(
                        bottom: 8,
                        child: Text('Drag to rotate',
                            style: TextStyle(color: Colors.black87)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Outfits', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final name in _collections.keys)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(name),
                      selected: collection == name,
                      onSelected: (_) => setState(() => collection = name),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 118,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final name in _collections[collection]!)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => _chooseCostume(name),
                        child: Container(
                          width: 103,
                          decoration: BoxDecoration(
                            color: style['costume'] == name
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 75,
                                child: Icon(
                                  _collections['Formal']!.contains(name)
                                      ? Icons.checkroom_rounded
                                      : _collections['Halloween']!
                                              .contains(name)
                                          ? Icons.nights_stay_rounded
                                          : _collections['Casual']!
                                                  .contains(name)
                                              ? Icons.person_rounded
                                              : Icons.shield_rounded,
                                  size: 42,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Text(_costumeNames[name]!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text('Presentation',
                style: Theme.of(context).textTheme.titleMedium),
            Wrap(spacing: 7, children: [
              for (final value in ['female', 'male', 'neutral'])
                ChoiceChip(
                  label: Text(value),
                  selected: style['presentation'] == value,
                  onSelected: (_) => _presentation(value),
                ),
            ]),
            _choices('Skin tone', 'skin', ['light', 'tan', 'brown', 'deep']),
            _choices(
                'Hair', 'hair', ['short', 'curly', 'long', 'bun', 'spiky']),
            _choices('Hair color', 'hairColor',
                ['black', 'brown', 'blonde', 'purple', 'red']),
            _choices('Eyes', 'eyes', ['round', 'sleepy', 'wide', 'wink']),
            _choices('Top', 'outfit', [
              'hoodie',
              'jacket',
              'dress',
              'tee',
              'suit',
              'armor',
              'cape',
              'robe',
              'creature'
            ]),
            _choices('Top color', 'outfitColor',
                ['violet', 'blue', 'coral', 'green', 'yellow']),
            _choices('Bottoms', 'bottoms', ['jeans', 'shorts', 'skirt']),
            _choices('Bottom color', 'bottomColor',
                ['blue', 'black', 'beige', 'purple']),
            _choices(
                'Shoes', 'shoes', ['sneakers', 'boots', 'formal', 'sandals']),
            _choices('Accessories', 'accessory', [
              'none',
              'glasses',
              'sunglasses',
              'hat',
              'mask',
              'cape',
              'wings'
            ]),
            _slider('Body width', 'bodyWidth', 1, 100),
            _slider('Head size', 'headSize', 1, 100),
            _slider('Rotation', 'rotation', -180, 180),
            const SizedBox(height: 14),
            Text('Pose', style: Theme.of(context).textTheme.titleMedium),
            Wrap(spacing: 7, children: [
              for (final pose in ['stand', 'wave', 'dance', 'hands-up'])
                ChoiceChip(
                  label: Text(pose),
                  selected: style['pose'] == pose,
                  onSelected: (_) => _pose(pose),
                ),
            ]),
            _slider('Left arm', 'leftArm', -90, 90),
            _slider('Right arm', 'rightArm', -90, 90),
            _slider('Left leg', 'leftLeg', -90, 90),
            _slider('Right leg', 'rightLeg', -90, 90),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.onCustomPhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Use my photo instead'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
}

class _V {
  const _V(this.x, this.y, this.z);
  final double x, y, z;
  _V operator +(_V b) => _V(x + b.x, y + b.y, z + b.z);
  _V operator -(_V b) => _V(x - b.x, y - b.y, z - b.z);
  _V operator *(double n) => _V(x * n, y * n, z * n);
}

class _Face {
  const _Face(this.points, this.depth, this.color);
  final List<Offset> points;
  final double depth;
  final Color color;
}

class _Avatar3DPainter extends CustomPainter {
  _Avatar3DPainter(this.style, this.compact);
  final Map<String, dynamic> style;
  final bool compact;
  final List<_Face> faces = [];
  late Size size;
  late double yaw;

  Color _color(String key, Map<String, Color> palette, String fallback) =>
      palette[style[key]] ?? palette[fallback]!;

  _V _turn(_V p) => _V(
        p.x * math.cos(yaw) + p.z * math.sin(yaw),
        p.y,
        -p.x * math.sin(yaw) + p.z * math.cos(yaw),
      );

  Offset _project(_V p) {
    final q = _turn(p);
    final scale =
        (compact ? size.width / 1.45 : size.width / 2.65) * (3.6 / (3.6 - q.z));
    return Offset(
      size.width / 2 + q.x * scale,
      (compact ? size.height * .76 : size.height * .52) - q.y * scale,
    );
  }

  void _ellipsoid(_V center, _V radius, Color color,
      {int latitudes = 14, int longitudes = 22}) {
    final vertices = <_V>[];
    for (var i = 0; i <= latitudes; i++) {
      final phi = math.pi * i / latitudes;
      for (var j = 0; j <= longitudes; j++) {
        final theta = 2 * math.pi * j / longitudes;
        vertices.add(_V(
          center.x + radius.x * math.sin(phi) * math.cos(theta),
          center.y + radius.y * math.cos(phi),
          center.z + radius.z * math.sin(phi) * math.sin(theta),
        ));
      }
    }
    for (var i = 0; i < latitudes; i++) {
      for (var j = 0; j < longitudes; j++) {
        final a = i * (longitudes + 1) + j;
        final b = a + longitudes + 1;
        _triangle(
            vertices[a], vertices[b], vertices[a + 1], center, radius, color);
        _triangle(vertices[a + 1], vertices[b], vertices[b + 1], center, radius,
            color);
      }
    }
  }

  void _triangle(_V a, _V b, _V c, _V center, _V radius, Color color) {
    final avg =
        _V((a.x + b.x + c.x) / 3, (a.y + b.y + c.y) / 3, (a.z + b.z + c.z) / 3);
    final nx = (avg.x - center.x) / radius.x;
    final ny = (avg.y - center.y) / radius.y;
    final nz = (avg.z - center.z) / radius.z;
    final light = (0.82 + nx * -.06 + ny * .08 + nz * .1).clamp(.62, 1.0);
    final lit = Color.fromARGB(
      255,
      (color.r * 255 * light).round().clamp(0, 255),
      (color.g * 255 * light).round().clamp(0, 255),
      (color.b * 255 * light).round().clamp(0, 255),
    );
    faces.add(_Face(
      [_project(a), _project(b), _project(c)],
      (_turn(a).z + _turn(b).z + _turn(c).z) / 3,
      lit,
    ));
  }

  void _bone(_V from, _V to, double thickness, Color color) {
    final center = (from + to) * .5;
    final delta = to - from;
    final length =
        math.sqrt(delta.x * delta.x + delta.y * delta.y + delta.z * delta.z);
    final angle = math.atan2(delta.x, delta.y);
    final radius = _V(thickness, length * .57, thickness);
    final vertex = <_V>[];
    const n = 12;
    const m = 18;
    for (var i = 0; i <= n; i++) {
      final phi = math.pi * i / n;
      for (var j = 0; j <= m; j++) {
        final theta = 2 * math.pi * j / m;
        final x = radius.x * math.sin(phi) * math.cos(theta);
        final y = radius.y * math.cos(phi);
        vertex.add(_V(
            center.x + x * math.cos(angle) + y * math.sin(angle),
            center.y - x * math.sin(angle) + y * math.cos(angle),
            center.z + radius.z * math.sin(phi) * math.sin(theta)));
      }
    }
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < m; j++) {
        final a = i * (m + 1) + j;
        final b = a + m + 1;
        _triangle(vertex[a], vertex[b], vertex[a + 1], center,
            _V(thickness, length * .57, thickness), color);
        _triangle(vertex[a + 1], vertex[b], vertex[b + 1], center,
            _V(thickness, length * .57, thickness), color);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size canvasSize) {
    size = canvasSize;
    yaw = (style['rotation'] as num).toDouble() * math.pi / 180;
    faces.clear();
    const skinColors = <String, Color>{
      'light': Color(0xFFF4C8AD),
      'tan': Color(0xFFDE9F71),
      'brown': Color(0xFFA86645),
      'deep': Color(0xFF633A2A),
    };
    const hairColors = <String, Color>{
      'black': Color(0xFF28232F),
      'brown': Color(0xFF67422F),
      'blonde': Color(0xFFD4A853),
      'purple': Color(0xFF7041A4),
      'red': Color(0xFFB85B46),
    };
    const topColors = <String, Color>{
      'violet': Color(0xFF7844B9),
      'blue': Color(0xFF3976BF),
      'coral': Color(0xFFE66368),
      'green': Color(0xFF329775),
      'yellow': Color(0xFFE5B83B),
    };
    const bottomColors = <String, Color>{
      'blue': Color(0xFF3C5D88),
      'black': Color(0xFF33313A),
      'beige': Color(0xFFC6A781),
      'purple': Color(0xFF624794),
    };
    final skin = _color('skin', skinColors, 'tan');
    final hair = _color('hairColor', hairColors, 'black');
    final top = _color('outfitColor', topColors, 'violet');
    final bottom = _color('bottomColor', bottomColors, 'blue');
    final width = (.32 + (style['bodyWidth'] as num).toDouble() * .0014) *
        (style['presentation'] == 'female' ? .9 : 1.0);
    final head = .33 + (style['headSize'] as num).toDouble() * .0013;
    final hairstyle = style['hair'] as String? ?? 'short';
    final accessory = style['accessory'] as String? ?? 'none';
    final outfit = style['outfit'] as String? ?? 'hoodie';
    final shoes = style['shoes'] as String? ?? 'sneakers';
    final shoeColor = shoes == 'formal'
        ? const Color(0xFF211C25)
        : shoes == 'sandals'
            ? skin
            : const Color(0xFFEEE9E4);
    if (!compact) {
      for (final side in [-1, 1]) {
        final legAngle =
            (style[side < 0 ? 'leftLeg' : 'rightLeg'] as num).toDouble() *
                math.pi /
                180;
        final hip = _V(side * width * .48, -.48, 0);
        final foot = _V(hip.x + math.sin(legAngle) * .27, -1.28, .02);
        _bone(hip, foot, .12, bottom);
        _ellipsoid(_V(foot.x, -1.3, .12), const _V(.16, .075, .23), shoeColor);
      }
      if (style['bottoms'] == 'skirt' ||
          outfit == 'dress' ||
          outfit == 'robe') {
        _ellipsoid(const _V(0, -.65, 0), _V(width * 1.3, .35, .28),
            outfit == 'dress' || outfit == 'robe' ? top : bottom);
      }
      if (accessory == 'cape' || outfit == 'cape') {
        _ellipsoid(const _V(0, -.1, -.31), const _V(.51, .72, .09),
            const Color(0xFFB74364));
      }
      if (accessory == 'wings') {
        for (final side in [-1, 1]) {
          _ellipsoid(_V(side * .49, .0, -.27), const _V(.26, .52, .08),
              const Color(0xFFE78A56));
        }
      }
      for (final side in [-1, 1]) {
        final armAngle =
            (style[side < 0 ? 'leftArm' : 'rightArm'] as num).toDouble() *
                math.pi /
                180;
        final shoulder = _V(side * (width + .05), .26, 0);
        final hand = _V(shoulder.x + side * math.cos(armAngle) * .37,
            shoulder.y - math.sin(armAngle) * .39, .05);
        _bone(shoulder, hand, .105, top);
        _ellipsoid(hand, const _V(.095, .095, .095), skin);
      }
      _ellipsoid(const _V(0, -.06, 0), _V(width, .55, .26), top);
      if (outfit == 'suit' || outfit == 'jacket') {
        _ellipsoid(const _V(0, .10, .253), const _V(.10, .20, .026),
            const Color(0xFFF5F0ED));
        if (outfit == 'suit') {
          _ellipsoid(const _V(0, .09, .282), const _V(.025, .17, .018),
              const Color(0xFFAF4963));
        }
      }
      if (outfit == 'armor' || outfit == 'creature') {
        _ellipsoid(
            const _V(0, .08, .27),
            const _V(.17, .17, .04),
            outfit == 'armor'
                ? const Color(0xFFE8D7A8)
                : const Color(0xFFFFECA0));
      }
      _ellipsoid(const _V(0, .52, 0), const _V(.115, .16, .12), skin);
    }
    if (hairstyle == 'long') {
      _ellipsoid(const _V(0, .79, -.12),
          _V(head * 1.13, head * 1.65, head * .88), hair);
    }
    _ellipsoid(const _V(0, .9, 0), _V(head, head * 1.1, head * .88), skin);
    if (hairstyle == 'long') {
      for (final side in [-1, 1]) {
        _ellipsoid(_V(side * head * .85, .86, head * .22),
            const _V(.085, .40, .13), hair);
      }
    }
    _ellipsoid(const _V(0, 1.13, -.03),
        _V(head * 1.03, hairstyle == 'spiky' ? .22 : .16, head * .9), hair);
    if (hairstyle == 'bun') {
      _ellipsoid(const _V(0, 1.42, -.08), const _V(.18, .16, .17), hair);
    } else if (hairstyle == 'curly' || hairstyle == 'spiky') {
      for (var i = -2; i <= 2; i++) {
        _ellipsoid(_V(i * head * .35, 1.26 + (i.isEven ? .07 : 0), .06),
            _V(.12, hairstyle == 'spiky' ? .18 : .13, .13), hair);
      }
    }
    for (final side in [-1, 1]) {
      _ellipsoid(_V(side * head * .93, .9, 0), const _V(.075, .11, .085), skin);
      if (!(style['eyes'] == 'wink' && side == 1)) {
        _ellipsoid(_V(side * head * .42, .96, head * .87),
            const _V(.055, .045, .022), Colors.white);
        _ellipsoid(
            _V(side * head * .42, .96, head * .93),
            _V(style['eyes'] == 'wide' ? .027 : .023, .027, .016),
            const Color(0xFF2D2540));
      }
      _ellipsoid(_V(side * head * .46, 1.075, head * .86),
          const _V(.095, .025, .025), hair);
    }
    _ellipsoid(_V(0, .78, head * .89), const _V(.045, .057, .04), skin);
    _ellipsoid(_V(0, .66, head * .86), const _V(.09, .02, .02),
        const Color(0xFF8D4855));
    if (accessory == 'glasses' ||
        accessory == 'sunglasses' ||
        accessory == 'mask') {
      for (final side in [-1, 1]) {
        _ellipsoid(
            _V(side * head * .43, .96, head * 1.02),
            const _V(.12, .095, .032),
            accessory == 'glasses'
                ? const Color(0xFF46404A)
                : const Color(0xFF292735));
      }
      _ellipsoid(_V(0, .96, head * 1.03), const _V(.09, .025, .025),
          const Color(0xFF2A2732));
    }
    if (accessory == 'hat') {
      _ellipsoid(
          const _V(0, 1.27, .03), _V(head * 1.35, .06, head * 1.12), hair);
      _ellipsoid(const _V(0, 1.41, 0), const _V(.21, .17, .21), hair);
    }
    faces.sort((a, b) => a.depth.compareTo(b.depth));
    for (final face in faces) {
      canvas.drawPath(
        Path()..addPolygon(face.points, true),
        Paint()
          ..color = face.color
          ..isAntiAlias = false,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Avatar3DPainter oldDelegate) =>
      oldDelegate.style.toString() != style.toString() ||
      oldDelegate.compact != compact;
}
