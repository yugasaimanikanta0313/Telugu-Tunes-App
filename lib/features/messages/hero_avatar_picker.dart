import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'avatar_editor.dart';

const heroAvatarNames = <String, String>{
  'spiderman': 'Spider-Man',
  'ironman': 'Iron Man',
  'batman': 'Batman',
  'hulk': 'Hulk',
  'drdoom': 'Doctor Doom',
  'loki': 'Loki',
  'doraemon': 'Doraemon',
  'wonderwoman': 'Wonder Woman',
  'pikachu': 'Pikachu',
};

String? heroAvatarImage(String? id) =>
    heroAvatarNames.containsKey(id) ? 'assets/hero_avatars/$id.png' : null;

class HeroAvatarPicker extends StatefulWidget {
  const HeroAvatarPicker({
    super.key,
    this.initialPreset,
    this.initialStyle,
    required this.onSave,
    required this.onSaveCustom,
    required this.onCustomPhoto,
  });

  final String? initialPreset;
  final Map<String, dynamic>? initialStyle;
  final Future<void> Function(String) onSave;
  final Future<void> Function(Map<String, dynamic>) onSaveCustom;
  final VoidCallback onCustomPhoto;

  @override
  State<HeroAvatarPicker> createState() => _HeroAvatarPickerState();
}

class _HeroAvatarPickerState extends State<HeroAvatarPicker> {
  late String selected = heroAvatarNames.containsKey(widget.initialPreset)
      ? widget.initialPreset!
      : 'spiderman';
  VideoPlayerController? player;
  bool saving = false;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    _select(selected);
  }

  Future<void> _select(String id) async {
    final currentGeneration = ++generation;
    final previous = player;
    setState(() {
      selected = id;
      player = null;
    });
    await previous?.dispose();
    if (id == 'drdoom' || !mounted || currentGeneration != generation) return;
    final next = VideoPlayerController.asset('assets/hero_avatars/$id.mp4');
    try {
      await next.initialize();
      if (!mounted || currentGeneration != generation) {
        await next.dispose();
        return;
      }
      await next.setLooping(true);
      await next.setVolume(0);
      setState(() => player = next);
      await next.play();
    } catch (_) {
      await next.dispose();
      if (mounted && currentGeneration == generation) setState(() {});
    }
  }

  @override
  void dispose() {
    generation++;
    player?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await widget.onSave(selected);
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

  @override
  Widget build(BuildContext context) {
    final thumbnail = heroAvatarImage(selected)!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose your avatar'),
        actions: [
          TextButton(
              onPressed: saving ? null : _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              width: 350,
              height: 390,
              decoration: BoxDecoration(
                color: const Color(0xFF261C33),
                borderRadius: BorderRadius.circular(26),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(thumbnail, fit: BoxFit.contain),
                    if (player?.value.isInitialized == true)
                      AspectRatio(
                        aspectRatio: player!.value.aspectRatio,
                        child: VideoPlayer(player!),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(heroAvatarNames[selected]!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Original animation supplied by you',
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth < 520 ? 3 : 5;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                childAspectRatio: 0.78,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: heroAvatarNames.length,
              itemBuilder: (context, index) {
                final id = heroAvatarNames.keys.elementAt(index);
                return InkWell(
                  onTap: () => _select(id),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: Border.all(
                        color: id == selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Image.asset(heroAvatarImage(id)!,
                              fit: BoxFit.contain),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(heroAvatarNames[id]!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11)),
                      ),
                    ]),
                  ),
                );
              },
            );
          }),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AvatarEditorScreen(
                    initialStyle: widget.initialStyle,
                    onSave: widget.onSaveCustom,
                    onCustomPhoto: widget.onCustomPhoto,
                  ),
                )),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Create a custom avatar'),
          ),
          OutlinedButton.icon(
            onPressed: widget.onCustomPhoto,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Use my photo'),
          ),
        ],
      ),
    );
  }
}
