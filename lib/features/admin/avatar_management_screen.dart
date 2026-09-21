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
  List<Map<String, dynamic>> avatars = [];
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
    if (mounted)
      setState(() => avatars = r.statusCode == 200
          ? (jsonDecode(r.body) as List).cast<Map<String, dynamic>>()
          : []);
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
