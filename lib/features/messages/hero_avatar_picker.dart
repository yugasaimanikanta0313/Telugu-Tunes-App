import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

const heroAvatarNames = <String, String>{
  'batman': 'Batman',
  'doraemon': 'Doraemon',
  'ironman': 'Iron Man',
  'pikachu': 'Pikachu',
  'spiderman': 'Spider-Man',
  'superman': 'Superman',
  'wonderwoman': 'Wonder Woman',
};

String? heroAvatarImage(String? id) =>
    heroAvatarNames.containsKey(id) ? 'assets/hero_avatars/$id.png' : null;
String? heroAvatarModel(String? id) =>
    heroAvatarNames.containsKey(id) ? 'assets/avatar_models/$id.glb' : null;
String? heroAvatarFace(String? id) => heroAvatarNames.containsKey(id)
    ? 'assets/hero_avatars/${id}_face.png'
    : null;

class HeroAvatarPicker extends StatefulWidget {
  const HeroAvatarPicker(
      {super.key,
      this.initialPreset,
      required this.onSave,
      required this.onCustomPhoto});
  final String? initialPreset;
  final Future<void> Function(String) onSave;
  final VoidCallback onCustomPhoto;
  @override
  State<HeroAvatarPicker> createState() => _HeroAvatarPickerState();
}

class _HeroAvatarPickerState extends State<HeroAvatarPicker> {
  late String selected = heroAvatarNames.containsKey(widget.initialPreset)
      ? widget.initialPreset!
      : 'ironman';
  bool saving = false;

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await widget.onSave(selected);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save avatar: $error')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = heroAvatarNames[selected]!;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your 3D avatar'), actions: [
        TextButton(onPressed: saving ? null : _save, child: const Text('Save')),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
            child: Container(
          width: 360,
          height: 420,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              color: const Color(0xFF21162E),
              borderRadius: BorderRadius.circular(26)),
          child: ModelViewer(
            key: ValueKey(selected),
            src: heroAvatarModel(selected)!,
            poster: heroAvatarImage(selected),
            alt: 'Interactive 3D $name avatar',
            loading: Loading.eager,
            reveal: Reveal.auto,
            cameraControls: true,
            disablePan: true,
            autoRotate: false,
            autoPlay: true,
            shadowIntensity: 1,
            exposure: 1.1,
            backgroundColor: const Color(0xFF21162E),
          ),
        )),
        const SizedBox(height: 12),
        Text(name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
        const Text('Drag to inspect the 3D model', textAlign: TextAlign.center),
        const SizedBox(height: 20),
        GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: .72,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8),
            itemCount: heroAvatarNames.length,
            itemBuilder: (context, index) {
              final id = heroAvatarNames.keys.elementAt(index);
              return InkWell(
                  onTap: () => setState(() => selected = id),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                      decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          border: Border.all(
                              color: id == selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: 3),
                          borderRadius: BorderRadius.circular(14)),
                      child: Column(children: [
                        Expanded(
                            child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Image.asset(heroAvatarImage(id)!,
                                    fit: BoxFit.contain))),
                        Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(heroAvatarNames[id]!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11))),
                      ])));
            }),
        const SizedBox(height: 20),
        OutlinedButton.icon(
            onPressed: widget.onCustomPhoto,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Use my photo')),
      ]),
    );
  }
}
