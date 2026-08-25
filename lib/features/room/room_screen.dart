import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../domain/models/music_models.dart';
import '../../state/music_controller.dart';
import '../shared/widgets.dart';

class RoomScreen extends StatelessWidget {
  const RoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    final room = controller.room;
    if (room == null) return _RoomLobby(controller: controller);
    return _ActiveRoom(controller: controller, room: room);
  }
}

class _ActiveRoom extends StatelessWidget {
  const _ActiveRoom({required this.controller, required this.room});

  final MusicController controller;
  final ListeningRoom room;

  bool get _isHost => room.host == controller.memberId;

  @override
  Widget build(BuildContext context) {
    final track = room.track;
    final roomColor = colorFromHex(track?.color ?? '7C4DFF');
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Listen together',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        room.isPublic
                            ? 'Anyone in Telugu Tunes can discover this room.'
                            : 'Only members with the invite code can join.',
                      ),
                    ],
                  ),
                ),
                Pill(
                  label: room.isPublic ? 'PUBLIC' : 'PRIVATE',
                  icon: room.isPublic
                      ? Icons.public_rounded
                      : Icons.lock_outline_rounded,
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [roomColor, const Color(0xff262540)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Pill(
                          label: 'LIVE NOW',
                          icon: Icons.graphic_eq_rounded,
                          color: Colors.white),
                      const Spacer(),
                      Text(
                          '${room.listeners} member${room.listeners == 1 ? '' : 's'}'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Artwork(
                        color: track?.color ?? '7C4DFF',
                        label: track?.album ?? 'Shared queue',
                        imageUrl: track?.artworkUrl ?? '',
                        size: 82,
                        icon: track == null
                            ? Icons.queue_music_rounded
                            : Icons.music_note_rounded,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(room.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(_isHost ? 'Your room' : 'You joined this room'),
                            const SizedBox(height: 7),
                            Text(
                              track == null
                                  ? 'Add the first song to begin'
                                  : 'Playing ${track.title}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              track == null ? null : () => controller.play(track),
                          icon: const Icon(Icons.headphones_rounded),
                          label: Text(track == null ? 'Add a song first' : 'Listen now'),
                        ),
                      ),
                      if (!room.isPublic && _isHost) ...[
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          onPressed: () => _copyCode(context, room.inviteCode),
                          tooltip: 'Share private invite code',
                          icon: const Icon(Icons.ios_share_rounded),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _AccessCard(room: room, isHost: _isHost),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: OutlinedButton.icon(
              onPressed: () => _leaveRoom(context),
              icon: Icon(_isHost ? Icons.stop_circle_outlined : Icons.logout_rounded),
              label: Text(_isHost ? 'Close room for everyone' : 'Leave this room'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SectionTitle(
              title: room.queue.isEmpty ? 'Shared queue' : 'Up next'),
        ),
        if (room.queue.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('No songs have been added yet.'),
            ),
          )
        else
          SliverList.builder(
            itemCount: room.queue.length,
            itemBuilder: (context, index) {
              final item = room.queue[index];
              return TrackTile(
                track: item,
                index: index + 1,
                onTap: () => controller.play(item),
                onMore: () => showTrackActions(context, item),
              );
            },
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: OutlinedButton.icon(
              onPressed: () => _showQueuePicker(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add songs to the shared queue'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _leaveRoom(BuildContext context) async {
    final action = _isHost ? 'Close room' : 'Leave room';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$action?'),
        content: Text(_isHost
            ? 'This ends “${room.name}” for every listener. You can create or join another room afterwards.'
            : 'You can join or create a different room afterwards.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<MusicController>().leaveRoom();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_isHost ? 'Room closed.' : 'You left the room.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', ''))));
      }
    }
  }

  static Future<void> _copyCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Private invite code copied.')));
    }
  }

  void _showQueuePicker(BuildContext context) {
    final controller = context.read<MusicController>();
    if (controller.allTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import music before adding songs.')));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .8),
          child: ListView(
            children: [
              const ListTile(
                  title: Text('Add to room queue',
                      style: TextStyle(fontWeight: FontWeight.w800))),
              ...controller.allTracks.map(
                (item) => ListTile(
                  leading: Artwork(
                      color: item.color,
                      label: item.album,
                      imageUrl: item.artworkUrl,
                      size: 42),
                  title: Text(item.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(item.artist,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () async {
                    try {
                      await controller.addToRoomQueue(item);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    } catch (error) {
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(
                            content: Text(error
                                .toString()
                                .replaceFirst('Bad state: ', ''))));
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({required this.room, required this.isHost});

  final ListeningRoom room;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    if (room.isPublic) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.public_rounded),
          title: Text('Public room'),
          subtitle: Text('Any signed-in Telugu Tunes member can see and join.'),
        ),
      );
    }
    if (!isHost) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.lock_outline_rounded),
          title: Text('Private room'),
          subtitle: Text('You joined with the owner’s private invite code.'),
        ),
      );
    }
    return Card(
      child: ListTile(
        leading: const Icon(Icons.key_rounded),
        title: const Text('Private invite code'),
        subtitle: Text(room.inviteCode),
        trailing: TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: room.inviteCode));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Private invite code copied.')));
            }
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy'),
        ),
      ),
    );
  }
}

class _RoomLobby extends StatelessWidget {
  const _RoomLobby({required this.controller});

  final MusicController controller;

  @override
  Widget build(BuildContext context) => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text('Listen together',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Create one room of your own or join one existing room. You can only be in one active room at a time.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Start your own room',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      const Text('Public rooms are discoverable. Private rooms use a shareable code.'),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final vertical = constraints.maxWidth < 430;
                          final publicButton = FilledButton.icon(
                            onPressed: () => _createRoom(context, true),
                            icon: const Icon(Icons.public_rounded),
                            label: const Text('Create public'),
                          );
                          final privateButton = OutlinedButton.icon(
                            onPressed: () => _createRoom(context, false),
                            icon: const Icon(Icons.lock_outline_rounded),
                            label: const Text('Create private'),
                          );
                          return vertical
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    publicButton,
                                    const SizedBox(height: 10),
                                    privateButton
                                  ])
                              : Row(children: [
                                  Expanded(child: publicButton),
                                  const SizedBox(width: 10),
                                  Expanded(child: privateButton)
                                ]);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: OutlinedButton.icon(
                onPressed: () => _joinPrivateRoom(context),
                icon: const Icon(Icons.key_rounded),
                label: const Text('Join private room with invite code'),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SectionTitle(title: 'Public rooms')),
          if (controller.publicRooms.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  child: ListTile(
                    leading: Icon(Icons.public_off_rounded),
                    title: Text('No public rooms right now'),
                    subtitle: Text('Create one so members can join without a code.'),
                  ),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: controller.publicRooms.length,
              itemBuilder: (context, index) {
                final room = controller.publicRooms[index];
                final track = room.track;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Card(
                    child: ListTile(
                      leading: Artwork(
                        color: track?.color ?? '7C4DFF',
                        label: track?.album ?? room.name,
                        imageUrl: track?.artworkUrl ?? '',
                        size: 48,
                        icon: Icons.public_rounded,
                      ),
                      title: Text(room.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(track == null
                          ? '${room.listeners} members • No song selected'
                          : '${room.listeners} members • Playing ${track.title}'),
                      trailing: FilledButton(
                        onPressed: () => _joinPublicRoom(context, room),
                        child: const Text('Join'),
                      ),
                    ),
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      );

  Future<void> _createRoom(BuildContext context, bool isPublic) async {
    final name = TextEditingController(text: '${controller.memberName}’s room');
    final created = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isPublic ? 'Create public room' : 'Create private room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isPublic
                ? 'Any signed-in member can discover and join this room. No code is needed.'
                : 'Only people you share the generated invite code with can join.'),
            const SizedBox(height: 14),
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Room name'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, name.text.trim()),
              child: const Text('Create')),
        ],
      ),
    );
    if (created == null || created.isEmpty || !context.mounted) return;
    try {
      await controller.createRoom(created, isPublic: isPublic);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isPublic
                ? 'Public room created.'
                : 'Private room created. Share its invite code.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', ''))));
      }
    }
  }

  Future<void> _joinPrivateRoom(BuildContext context) async {
    final code = TextEditingController();
    final inviteCode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join private room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ask the owner for their private invite code.'),
            const SizedBox(height: 14),
            TextField(
              controller: code,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Private invite code',
                hintText: 'Enter code, e.g. TUNE-ABC123',
                prefixIcon: Icon(Icons.key_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, code.text.trim()),
              child: const Text('Join and listen')),
        ],
      ),
    );
    if (inviteCode == null || inviteCode.isEmpty || !context.mounted) return;
    try {
      await controller.joinRoom(inviteCode);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Joined private room.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', ''))));
      }
    }
  }

  Future<void> _joinPublicRoom(BuildContext context, ListeningRoom room) async {
    try {
      await controller.joinPublicRoom(room.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Joined ${room.name}.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', ''))));
      }
    }
  }
}
