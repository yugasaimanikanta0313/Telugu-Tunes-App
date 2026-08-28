import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/music_controller.dart';
import '../../data/services/api_music_service.dart';
import '../auth/sign_in_screen.dart';
import '../admin/member_management_screen.dart';
import '../admin/recommended_playlists_screen.dart';
import '../import/import_music_sheet.dart';
import '../shared/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.onSignOut, this.onSignIn});
  final Future<void> Function()? onSignOut;
  final ValueChanged<ApiSession>? onSignIn;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool wifiOnly = true;
  bool lossless = false;
  bool smartDownloads = true;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
      children: [
        Text('Settings',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        const SectionTitle(title: 'Account'),
        Card(
          child: ListTile(
            leading: CircleAvatar(
                child: Icon(controller.isAuthenticated
                    ? Icons.person_rounded
                    : Icons.person_outline_rounded)),
            title: Text(controller.memberName),
            subtitle: Text(controller.isAuthenticated
                ? 'Account bound • playlists, favorites and rooms enabled'
                : 'Guest mode • listening does not require an account'),
            trailing: TextButton(
                onPressed: controller.isAuthenticated
                    ? widget.onSignOut
                    : widget.onSignIn == null
                        ? null
                        : () => _openSignIn(widget.onSignIn!),
                child: Text(
                    controller.isAuthenticated ? 'Sign out' : 'Bind account')),
          ),
        ),
        if (controller.isAdmin) ...[
          const SectionTitle(title: 'Administration'),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text('Manage member accounts'),
                subtitle:
                    const Text('Administrator access and active accounts'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MemberManagementScreen()),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.recommend_outlined),
                title: const Text('Manage recommended playlists'),
                subtitle:
                    const Text('Choose category, subtype and catalog songs'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RecommendedPlaylistsScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Export metadata backup'),
                subtitle: const Text(
                    'Songs, albums, playlists and lyrics; audio stays in S3'),
                trailing: const Icon(Icons.download_rounded),
                onTap: () => _exportBackup(controller),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.restore_rounded),
                title: const Text('Restore metadata backup'),
                subtitle: const Text('Safely merges a Telugu Tunes JSON file'),
                trailing: const Icon(Icons.upload_file_rounded),
                onTap: () => _restoreBackup(controller),
              ),
            ]),
          ),
        ],
        const SectionTitle(title: 'Playback & downloads'),
        Card(
          child: Column(children: [
            SwitchListTile(
              value: wifiOnly,
              onChanged: (value) => setState(() => wifiOnly = value),
              secondary: const Icon(Icons.wifi_rounded),
              title: const Text('Download on Wi-Fi only'),
              subtitle: const Text('Use mobile data only when you choose'),
            ),
            const Divider(height: 1),
            SwitchListTile(
              value: smartDownloads,
              onChanged: (value) => setState(() => smartDownloads = value),
              secondary: const Icon(Icons.auto_awesome_rounded),
              title: const Text('Smart downloads'),
              subtitle: const Text('Keep your recent private music offline'),
            ),
            const Divider(height: 1),
            SwitchListTile(
              value: lossless,
              onChanged: (value) => setState(() => lossless = value),
              secondary: const Icon(Icons.high_quality_rounded),
              title: const Text('Higher audio quality'),
              subtitle:
                  const Text('Applied when your storage backend supports it'),
            ),
            const Divider(height: 1),
            const ListTile(
              leading: Icon(Icons.queue_music_rounded),
              title: Text('Gapless queue'),
              subtitle: Text('The next song is prepared before this one ends'),
              trailing: Icon(Icons.check_circle_rounded),
            ),
            const Divider(height: 1),
            const ListTile(
              leading: Icon(Icons.palette_outlined),
              title: Text('Artwork-based theme'),
              subtitle: Text('Player colors follow the current cover art'),
              trailing: Icon(Icons.check_circle_rounded),
            ),
          ]),
        ),
        const SectionTitle(title: 'Your music'),
        Card(
          child: Column(children: [
            if (controller.isAdmin)
              ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded),
                  title: const Text('Add or import music'),
                  subtitle:
                      const Text('Files, folders, Drive or metadata links'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showImportMusicSheet(context)),
            const Divider(height: 1),
            ListTile(
                leading: const Icon(Icons.storage_rounded),
                title: const Text('Offline storage'),
                subtitle: Text(controller.downloaded.length.toString() +
                    ' tracks saved on this device'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Downloaded songs remain available without internet.')))),
            const Divider(height: 1),
            const ListTile(
              leading: Icon(Icons.memory_rounded),
              title: Text('Bounded cache memory'),
              subtitle: Text(
                  'Artwork memory capped at 80 MB; streamed audio reuses a 1-hour private cache'),
              trailing: Icon(Icons.check_circle_rounded),
            ),
          ]),
        ),
        const SectionTitle(title: 'Connection status'),
        Card(
          child: Column(children: [
            ListTile(
                leading: Icon(Icons.check_circle_rounded,
                    color: Theme.of(context).colorScheme.primary),
                title: const Text('Flutter client'),
                subtitle: Text(controller.remoteMode
                    ? 'API mode • connected'
                    : 'Local demo mode • ready')),
            const Divider(height: 1),
            ListTile(
                leading: Icon(controller.remoteMode
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_off_rounded),
                title: const Text('Spring Boot API'),
                subtitle: Text(controller.remoteMode
                    ? controller.apiBaseUrl
                    : 'Unavailable — running local demo data')),
            const Divider(height: 1),
            const ListTile(
                leading: Icon(Icons.dns_outlined),
                title: Text('MongoDB Atlas metadata'),
                subtitle: Text('Connect through the API only')),
            const Divider(height: 1),
            const ListTile(
                leading: Icon(Icons.add_to_drive_outlined),
                title: Text('Google Drive audio'),
                subtitle: Text('Connect through signed backend URLs')),
            const Divider(height: 1),
            ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('Gemini assistance'),
                subtitle: Text(controller.remoteMode
                    ? 'Requests go through the private backend'
                    : 'Available after the backend connects')),
          ]),
        ),
        const SectionTitle(title: 'About this V1'),
        Text(
            'No audio or copyrighted artwork is bundled. The current catalog is fictional metadata and generated color artwork only.',
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4)),
      ],
    );
  }

  Future<void> _openSignIn(ValueChanged<ApiSession> onSignIn) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SignInScreen(
          onAuthenticated: (session) {
            Navigator.pop(context);
            onSignIn(session);
          },
        ),
      ),
    );
  }

  Future<void> _exportBackup(MusicController controller) async {
    try {
      final bytes = await controller.exportBackup();
      await FilePicker.saveFile(
        dialogTitle: 'Save Telugu Tunes backup',
        fileName: 'telugu-tunes-backup.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: bytes,
      );
      if (mounted) _showMessage('Metadata backup exported.');
    } catch (error) {
      if (mounted) _showMessage(_cleanError(error), error: true);
    }
  }

  Future<void> _restoreBackup(MusicController controller) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (picked == null || !mounted) return;
    final bytes = picked.files.single.bytes;
    if (bytes == null) {
      _showMessage('Could not read the selected backup.', error: true);
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Restore this backup?'),
            content: const Text(
                'Songs, albums, playlists and lyrics will be merged. Existing records not present in the backup will not be deleted.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Restore'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await controller.restoreBackup(bytes);
      if (mounted) _showMessage('Backup restored and catalog refreshed.');
    } catch (error) {
      if (mounted) _showMessage(_cleanError(error), error: true);
    }
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Bad state: ', '');

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }
}
