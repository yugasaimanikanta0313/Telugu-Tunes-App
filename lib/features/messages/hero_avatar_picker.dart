import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

const heroAvatarNames = <String, String>{
  'batman': 'Batman',
  'doraemon': 'Doraemon',
  'hulk': 'Hulk',
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
      required this.name,
      required this.email,
      this.initialDateOfBirth,
      this.initialCity = '',
      this.managedAvatars = const [],
      this.hiddenBundled = const {},
      required this.apiBaseUrl,
      required this.onSave,
      required this.onSaveDetails,
      required this.onCustomPhoto});
  final String? initialPreset;
  final String name;
  final String email;
  final String? initialDateOfBirth;
  final String initialCity;
  final List<Map<String, dynamic>> managedAvatars;
  final Set<String> hiddenBundled;
  final String apiBaseUrl;
  final Future<void> Function(String) onSave;
  final Future<void> Function(String, String) onSaveDetails;
  final VoidCallback onCustomPhoto;
  @override
  State<HeroAvatarPicker> createState() => _HeroAvatarPickerState();
}

class _HeroAvatarPickerState extends State<HeroAvatarPicker> {
  late String selected = widget.initialPreset ?? 'ironman';
  bool saving = false;
  late final TextEditingController city =
      TextEditingController(text: widget.initialCity);
  DateTime? dateOfBirth;

  @override
  void initState() {
    super.initState();
    dateOfBirth = DateTime.tryParse(widget.initialDateOfBirth ?? '');
  }

  @override
  void dispose() {
    city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      if (dateOfBirth == null || city.text.trim().isEmpty) {
        throw StateError('Choose your date of birth and enter your city.');
      }
      final dob =
          '${dateOfBirth!.year.toString().padLeft(4, '0')}-${dateOfBirth!.month.toString().padLeft(2, '0')}-${dateOfBirth!.day.toString().padLeft(2, '0')}';
      await widget.onSaveDetails(dob, city.text.trim());
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
    final managed = {
      for (final value in widget.managedAvatars) value['id'].toString(): value
    };
    final visibleBundled = heroAvatarNames.keys
        .where((id) => !widget.hiddenBundled.contains(id))
        .toList();
    if (widget.hiddenBundled.contains(selected) ||
        (!heroAvatarNames.containsKey(selected) &&
            !managed.containsKey(selected))) {
      selected = visibleBundled.isNotEmpty
          ? visibleBundled.first
          : (managed.isNotEmpty ? managed.keys.first : selected);
    }
    final name = heroAvatarNames[selected] ??
        managed[selected]?['name']?.toString() ??
        'Avatar';
    final model = heroAvatarModel(selected) ??
        '${widget.apiBaseUrl}/avatar-catalog/public/$selected/model';
    final ids = [...visibleBundled, ...managed.keys];
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your 3D avatar'), actions: [
        TextButton(onPressed: saving ? null : _save, child: const Text('Save')),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextFormField(
            initialValue: widget.name,
            readOnly: true,
            decoration:
                const InputDecoration(labelText: 'Name from registration')),
        const SizedBox(height: 10),
        TextFormField(
            initialValue: widget.email,
            readOnly: true,
            decoration:
                const InputDecoration(labelText: 'Gmail from registration')),
        const SizedBox(height: 10),
        TextFormField(
            controller: city,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'City')),
        const SizedBox(height: 10),
        OutlinedButton.icon(
            onPressed: () async {
              final chosen = await showDatePicker(
                  context: context,
                  firstDate: DateTime(DateTime.now().year - 120),
                  lastDate: DateTime.now(),
                  initialDate:
                      dateOfBirth ?? DateTime(DateTime.now().year - 18));
              if (chosen != null) setState(() => dateOfBirth = chosen);
            },
            icon: const Icon(Icons.cake_outlined),
            label: Text(dateOfBirth == null
                ? 'Choose date of birth'
                : '${dateOfBirth!.day}/${dateOfBirth!.month}/${dateOfBirth!.year}')),
        const SizedBox(height: 18),
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
            src: model,
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
            itemCount: ids.length,
            itemBuilder: (context, index) {
              final id = ids[index];
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
                                child: heroAvatarImage(id) == null
                                    ? const Icon(Icons.view_in_ar_rounded,
                                        size: 48)
                                    : Image.asset(heroAvatarImage(id)!,
                                        fit: BoxFit.contain))),
                        Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                                heroAvatarNames[id] ??
                                    managed[id]?['name']?.toString() ??
                                    'Avatar',
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
