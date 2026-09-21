import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../state/music_controller.dart';

class AvatarManagementScreen extends StatefulWidget {
  const AvatarManagementScreen({super.key});
  @override
  State<AvatarManagementScreen> createState() => _AvatarManagementScreenState();
}

class _AvatarManagementScreenState extends State<AvatarManagementScreen> {
  static const bundled = <String, String>{
    'batman': 'Batman',
    'doraemon': 'Doraemon',
    'hulk': 'Hulk',
    'ironman': 'Iron Man',
    'pikachu': 'Pikachu',
    'spiderman': 'Spider-Man',
    'superman': 'Superman',
    'wonderwoman': 'Wonder Woman'
  };
  List<Map<String, dynamic>> avatars = [];
  Set<String> hiddenBundled = {};
  bool busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final c = context.read<MusicController>();
    final r =
        await http.get(Uri.parse('${c.apiBaseUrl}/avatar-catalog/public'));
    final hidden = await http
        .get(Uri.parse('${c.apiBaseUrl}/avatar-catalog/public/hidden-bundled'));
    if (mounted)
      setState(() {
        avatars = r.statusCode == 200
            ? (jsonDecode(r.body) as List).cast<Map<String, dynamic>>()
            : [];
        hiddenBundled = hidden.statusCode == 200
            ? (jsonDecode(hidden.body) as List)
                .map((value) => value.toString())
                .toSet()
            : {};
      });
  }

  Future<void> _upload() async {
    final picked = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['glb'], withData: true);
    if (picked == null || picked.files.first.bytes == null || !mounted) return;
    final name = TextEditingController(
        text: picked.files.first.name.replaceAll(RegExp(r'\.glb$'), ''));
    final title = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
                title: const Text('Avatar name'),
                content: TextField(controller: name),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(d),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(d, name.text.trim()),
                      child: const Text('Upload'))
                ]));
    name.dispose();
    if (title == null || title.isEmpty || !mounted) return;
    setState(() => busy = true);
    final c = context.read<MusicController>();
    final request = http.MultipartRequest(
        'POST', Uri.parse('${c.apiBaseUrl}/avatar-catalog'))
      ..headers['Authorization'] = 'Bearer ${c.authToken}'
      ..fields['name'] = title
      ..files.add(http.MultipartFile.fromBytes(
          'file', picked.files.first.bytes!,
          filename: picked.files.first.name));
    final response = await request.send();
    if (response.statusCode >= 300) throw StateError('Avatar upload failed.');
    if (mounted) setState(() => busy = false);
    await _load();
  }

  Future<void> _delete(String id) async {
    final c = context.read<MusicController>();
    await http.delete(Uri.parse('${c.apiBaseUrl}/avatar-catalog/$id'),
        headers: {'Authorization': 'Bearer ${c.authToken}'});
    await _load();
  }

  Future<void> _toggleBundled(String id) async {
    final c = context.read<MusicController>();
    final uri = Uri.parse('${c.apiBaseUrl}/avatar-catalog/bundled/$id');
    final headers = {'Authorization': 'Bearer ${c.authToken}'};
    if (hiddenBundled.contains(id)) {
      await http.post(Uri.parse('$uri/restore'), headers: headers);
    } else {
      await http.delete(uri, headers: headers);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Manage 3D avatars')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: busy ? null : _upload,
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload GLB')),
      body: ListView(children: [
        const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
                'Upload self-contained GLB models. They appear in avatar selection immediately, without redeploying the app.')),
        const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Bundled avatars',
                style: TextStyle(fontWeight: FontWeight.bold))),
        for (final entry in bundled.entries)
          ListTile(
              leading: const Icon(Icons.view_in_ar),
              title: Text(entry.value),
              subtitle: Text(hiddenBundled.contains(entry.key)
                  ? 'Removed from avatar selection'
                  : 'Available to users'),
              trailing: IconButton(
                  tooltip: hiddenBundled.contains(entry.key)
                      ? 'Restore avatar'
                      : 'Remove avatar',
                  icon: Icon(hiddenBundled.contains(entry.key)
                      ? Icons.restore
                      : Icons.delete_outline),
                  onPressed: () => _toggleBundled(entry.key))),
        const Divider(),
        const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Uploaded avatars',
                style: TextStyle(fontWeight: FontWeight.bold))),
        for (final a in avatars)
          ListTile(
              leading: const Icon(Icons.view_in_ar),
              title: Text(a['name']?.toString() ?? 'Avatar'),
              subtitle: Text(a['fileName']?.toString() ?? ''),
              trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(a['id'].toString())))
      ]));
}
