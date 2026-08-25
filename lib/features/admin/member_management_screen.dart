import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/music_models.dart';
import '../../state/music_controller.dart';

class MemberManagementScreen extends StatefulWidget {
  const MemberManagementScreen({super.key});

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  List<AdminMember> _members = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final members = await context.read<MusicController>().getAdminMembers();
      if (mounted) setState(() => _members = members);
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = error.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update(
    AdminMember member, {
    bool? active,
    bool? isAdmin,
  }) async {
    try {
      final updated = await context.read<MusicController>().updateAdminMember(
            member.id,
            active: active,
            isAdmin: isAdmin,
          );
      if (!mounted) return;
      setState(() => _members = [
            for (final value in _members)
              if (value.id == updated.id) updated else value,
          ]);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${updated.displayName} updated.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Member management')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      children: [
                        Text(
                          'Only administrators can edit or delete songs and albums. Members can add and listen to music.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 14),
                        for (final member in _members)
                          Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(member.displayName.isEmpty
                                    ? '?'
                                    : member.displayName[0].toUpperCase()),
                              ),
                              title: Text(member.displayName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                '${member.email}\n${member.isOwner ? 'Owner' : member.isAdmin ? 'Administrator' : 'Member'} • ${member.active ? 'Active' : 'Disabled'}',
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<_MemberAction>(
                                onSelected: (action) => switch (action) {
                                  _MemberAction.toggleAdmin =>
                                    _update(member, isAdmin: !member.isAdmin),
                                  _MemberAction.toggleActive =>
                                    _update(member, active: !member.active),
                                },
                                itemBuilder: (context) => [
                                  if (!member.isOwner)
                                    PopupMenuItem(
                                      value: _MemberAction.toggleAdmin,
                                      child: Text(member.isAdmin
                                          ? 'Remove administrator access'
                                          : 'Make administrator'),
                                    ),
                                  PopupMenuItem(
                                    value: _MemberAction.toggleActive,
                                    child: Text(member.active
                                        ? 'Disable account'
                                        : 'Enable account'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
      );
}

enum _MemberAction { toggleAdmin, toggleActive }

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 42),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}
