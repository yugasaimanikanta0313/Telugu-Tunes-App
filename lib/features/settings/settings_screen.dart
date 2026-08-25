import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/music_controller.dart';
import '../admin/member_management_screen.dart';
import '../import/import_music_sheet.dart';
import '../shared/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.onSignOut});
  final Future<void> Function()? onSignOut;

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
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Text('S')),
            title: Text(controller.memberName),
            subtitle: Text(controller.remoteMode
                ? 'Private circle • API profile active'
                : 'Local demo profile'),
            trailing: TextButton(
                onPressed: widget.onSignOut == null
                    ? null
                    : () async {
                        await widget.onSignOut!();
                      },
                child: const Text('Sign out')),
          ),
        ),
        if (controller.isAdmin) ...[
          const SectionTitle(title: 'Administration'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Manage member accounts'),
              subtitle: const Text('Administrator access and active accounts'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MemberManagementScreen()),
              ),
            ),
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
          ]),
        ),
        const SectionTitle(title: 'Your music'),
        Card(
          child: Column(children: [
            ListTile(
                leading: const Icon(Icons.add_circle_outline_rounded),
                title: const Text('Add or import music'),
                subtitle: const Text('Files, folders, Drive or metadata links'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showImportMusicSheet(context)),
            const Divider(height: 1),
            ListTile(
                leading: const Icon(Icons.storage_rounded),
                title: const Text('Offline storage'),
                subtitle: Text(controller.downloaded.length.toString() +
                    ' tracks currently marked'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Downloads are marked locally. Audio caching will activate after private storage is configured.')))),
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
}
