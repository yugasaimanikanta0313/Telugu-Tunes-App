import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../state/music_controller.dart';
import 'avatar_editor.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<dynamic> friends = [];
  String? error;
  Timer? refresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted)
        await requestChatAlertPermission(context.read<MusicController>());
    });
    refresh =
        Timer.periodic(const Duration(seconds: 8), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    refresh?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final controller = context.read<MusicController>();
      await flushChatQueue(controller);
      final api = _ChatApi(controller);
      final result = await api.get('/friends');
      await pollChatAlerts(controller, friendsResult: result as List);
      if (mounted)
        setState(() {
          friends = result;
          error = null;
        });
    } catch (e) {
      if (mounted && !silent) setState(() => error = e.toString());
    }
  }

  Future<void> _addFriend() async {
    final input = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a friend'),
        content: TextField(
            controller: input,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration:
                const InputDecoration(labelText: 'Friend’s Gmail address')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, input.text.trim()),
              child: const Text('Send request')),
        ],
      ),
    );
    input.dispose();
    if (email == null || email.isEmpty || !mounted) return;
    try {
      await _ChatApi(context.read<MusicController>())
          .post('/friends', {'email': email});
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _changeAvatar() async {
    final picked =
        await FilePicker.pickFiles(type: FileType.image, withData: true);
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final file = picked.files.first;
    if (file.bytes == null) return;
    try {
      await _ChatApi(context.read<MusicController>())
          .uploadAvatar(file.name, file.bytes!);
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat profile photo updated.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _chooseAvatar() async {
    try {
      final controller = context.read<MusicController>();
      final path = await Navigator.push<AvatarPath>(
          context,
          MaterialPageRoute(
              builder: (_) => AvatarPathScreen(
                    onSnapAvatar: (url) async {
                      await _ChatApi(controller)
                          .post('/avatar/snap', {'avatarUrl': url});
                      await _load();
                    },
                  )));
      if (path != AvatarPath.custom || !mounted) return;
      final person =
          await _ChatApi(controller).get('/avatar/me') as Map<String, dynamic>;
      if (!mounted) return;
      await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => AvatarEditorScreen(
              initialStyle: person['avatarStyle'] as Map<String, dynamic>?,
              onSave: (style) async {
                await _ChatApi(controller).post('/avatar/style', style);
                await _load();
              },
              onCustomPhoto: () {
                Navigator.pop(context);
                _changeAvatar();
              },
            ),
          ));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _accept(String id) async {
    try {
      await _ChatApi(context.read<MusicController>())
          .post('/friends/$id/accept', {});
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages'), actions: [
        IconButton(
            onPressed: _chooseAvatar,
            tooltip: 'Choose chat avatar or photo',
            icon: const Icon(Icons.account_circle_outlined)),
        IconButton(
            onPressed: _addFriend,
            tooltip: 'Add friend by Gmail',
            icon: const Icon(Icons.person_add_alt_1_rounded)),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          if (error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(error!)),
          if (friends.isEmpty)
            const Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                    'Add a friend using their Gmail address to start a private chat.')),
          for (final entry in friends)
            Builder(builder: (context) {
              final friend = entry as Map<String, dynamic>;
              final person = friend['person'] as Map<String, dynamic>;
              final accepted = friend['status'] == 'accepted';
              final last = friend['lastMessage'] as Map<String, dynamic>?;
              final unread = (friend['unreadCount'] as num?)?.toInt() ?? 0;
              return ListTile(
                leading: _Avatar(
                    name: person['name'] as String? ?? '?',
                    avatarId: person['avatarId'] as String? ?? '',
                    snapAvatarUrl: person['snapAvatarUrl'] as String? ?? '',
                    avatarStyle:
                        person['avatarStyle'] as Map<String, dynamic>?),
                title: Text(person['name'] as String? ?? ''),
                subtitle: Text(
                    accepted
                        ? last == null
                            ? 'Start your chat'
                            : _messagePreview(last,
                                mine: last['senderId'] ==
                                    context.read<MusicController>().memberId)
                        : friend['incoming'] == true
                            ? 'Friend request received'
                            : 'Request sent',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                trailing: accepted
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            if (last != null)
                              Text(
                                  _messageTime(
                                      last['createdAt'] as String? ?? ''),
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                            if (unread > 0)
                              CircleAvatar(
                                  radius: 11,
                                  child: Text('$unread',
                                      style: const TextStyle(fontSize: 11))),
                            if (unread == 0) const Icon(Icons.chevron_right),
                          ])
                    : friend['incoming'] == true
                        ? TextButton(
                            onPressed: () => _accept(friend['id'] as String),
                            child: const Text('Accept'))
                        : null,
                onTap: accepted
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => _ConversationScreen(peer: person)))
                    : null,
              );
            }),
        ]),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(
      {required this.name,
      this.avatarId = '',
      this.snapAvatarUrl = '',
      this.avatarStyle});
  final String name;
  final String avatarId;
  final String snapAvatarUrl;
  final Map<String, dynamic>? avatarStyle;
  @override
  Widget build(BuildContext context) {
    final api = _ChatApi(context.read<MusicController>());
    return CircleAvatar(
      foregroundImage: snapAvatarUrl.isNotEmpty
          ? NetworkImage(snapAvatarUrl)
          : avatarId.isEmpty
              ? null
              : NetworkImage('${api.base}/media/$avatarId',
                  headers: api.headers),
      child: AvatarFigure(style: avatarStyle, compact: true),
    );
  }
}

String _messagePreview(Map<String, dynamic> message, {required bool mine}) {
  final kind = message['kind'] as String? ?? 'text';
  final value = switch (kind) {
    'audio' => 'Voice message',
    'image' => 'Photo',
    'video' => 'Video',
    'file' => message['fileName'] as String? ?? 'File',
    'sticker' => 'Sticker ${message['text'] ?? ''}',
    _ => message['text'] as String? ?? '',
  };
  return '${mine ? 'You: ' : ''}$value';
}

String _messageTime(String timestamp) {
  final parsed = DateTime.tryParse(timestamp)?.toLocal();
  if (parsed == null) return '';
  final now = DateTime.now();
  if (now.difference(parsed).inDays > 0) return 'Yesterday';
  final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
  return '$hour:${parsed.minute.toString().padLeft(2, '0')} ${parsed.hour < 12 ? 'AM' : 'PM'}';
}

class _ConversationScreen extends StatefulWidget {
  const _ConversationScreen({required this.peer});
  final Map<String, dynamic> peer;
  @override
  State<_ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<_ConversationScreen>
    with WidgetsBindingObserver {
  static const _privacy = MethodChannel('telugu_tunes/chat_privacy');
  final input = TextEditingController();
  final recorder = AudioRecorder();
  List<dynamic> messages = [];
  Timer? refresh;
  bool sending = false;
  bool recording = false;
  String? error;

  String get peerId => widget.peer['id'] as String;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setSecure(true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    refresh =
        Timer.periodic(const Duration(seconds: 4), (_) => _load(silent: true));
  }

  Future<void> _setSecure(bool enabled) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _privacy.invokeMethod<void>('setSecure', {'enabled': enabled});
      } catch (_) {}
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _setSecure(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    refresh?.cancel();
    input.dispose();
    recorder.dispose();
    _setSecure(false);
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final api = _ChatApi(context.read<MusicController>());
      await flushChatQueue(context.read<MusicController>());
      final result = await api.get('/$peerId');
      await api.post('/$peerId/read', {});
      if (mounted)
        setState(() {
          messages = result as List;
          error = null;
        });
    } catch (e) {
      if (mounted && !silent) setState(() => error = '$e');
    }
  }

  Future<void> _queue(Map<String, dynamic> payload) async {
    final api = _ChatApi(context.read<MusicController>());
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_queue_${api.memberId}';
    final queued = jsonDecode(prefs.getString(key) ?? '[]') as List;
    queued.add(payload);
    await prefs.setString(key, jsonEncode(queued));
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Message queued. It will send when your connection returns.')));
  }

  Future<void> _send(String kind, String text,
      {String mediaId = '', String fileName = ''}) async {
    if (text.trim().isEmpty && mediaId.isEmpty) return;
    final controller = context.read<MusicController>();
    final api = _ChatApi(controller);
    final payload = <String, dynamic>{
      'peerId': peerId,
      'clientId':
          '${DateTime.now().microsecondsSinceEpoch}-${controller.memberId}',
      'kind': kind,
      'text': text.trim(),
      'mediaId': mediaId,
      'fileName': fileName,
    };
    input.clear();
    setState(() => sending = true);
    try {
      await api.post('/$peerId', payload);
      await _load();
    } catch (e) {
      if (e is _ChatHttpException && e.status < 500) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
      } else {
        await _queue(payload);
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _attach() async {
    final picked = await FilePicker.pickFiles(withData: true);
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    setState(() => sending = true);
    try {
      final extension = file.extension?.toLowerCase() ?? '';
      final kind = {'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(extension)
          ? 'image'
          : {'mp4', 'mov', 'webm'}.contains(extension)
              ? 'video'
              : {'mp3', 'm4a', 'wav', 'ogg'}.contains(extension)
                  ? 'audio'
                  : 'file';
      await _sendAttachment(kind, file.name, bytes);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (recording) {
        final path = await recorder.stop();
        if (mounted) setState(() => recording = false);
        if (path == null) return;
        final bytes = await File(path).readAsBytes();
        final name = 'voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _sendAttachment('audio', name, bytes);
      } else {
        if (!await recorder.hasPermission())
          throw StateError('Microphone permission is required.');
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
        await recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc),
            path: path);
        if (mounted) setState(() => recording = true);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _sendAttachment(
      String kind, String name, Uint8List bytes) async {
    try {
      final media =
          await _ChatApi(context.read<MusicController>()).upload(name, bytes);
      await _send(kind, kind == 'audio' ? 'Voice message' : name,
          mediaId: media['id'] as String, fileName: name);
    } catch (e) {
      if (e is _ChatHttpException && e.status < 500) rethrow;
      if (kIsWeb) rethrow;
      final dir = await getApplicationSupportDirectory();
      final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path =
          '${dir.path}/queued-${DateTime.now().microsecondsSinceEpoch}-$safeName';
      await File(path).writeAsBytes(bytes, flush: true);
      final controller = context.read<MusicController>();
      await _queue({
        'peerId': peerId,
        'clientId':
            '${DateTime.now().microsecondsSinceEpoch}-${controller.memberId}',
        'kind': kind,
        'text': kind == 'audio' ? 'Voice message' : name,
        'fileName': name,
        'localPath': path,
      });
    }
  }

  void _pickSticker() {
    const stickers = [
      '😀',
      '😍',
      '🥳',
      '😂',
      '❤️',
      '🔥',
      '👍',
      '🎵',
      '🙏',
      '🌟',
      '🐯',
      '🎉'
    ];
    showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final sticker in stickers)
                    InkWell(
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _send('sticker', sticker);
                      },
                      child:
                          Text(sticker, style: const TextStyle(fontSize: 42)),
                    )
                ]),
              ),
            ));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    return Scaffold(
      appBar: AppBar(
          title: Row(children: [
        _Avatar(
            name: widget.peer['name'] as String? ?? '?',
            avatarId: widget.peer['avatarId'] as String? ?? '',
            snapAvatarUrl: widget.peer['snapAvatarUrl'] as String? ?? '',
            avatarStyle: widget.peer['avatarStyle'] as Map<String, dynamic>?),
        const SizedBox(width: 10),
        Expanded(child: Text(widget.peer['name'] as String? ?? 'Chat')),
      ])),
      body: Column(children: [
        if (error != null)
          Padding(padding: const EdgeInsets.all(8), child: Text(error!)),
        Expanded(
            child: ListView.builder(
          reverse: true,
          padding: const EdgeInsets.all(12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message =
                messages[messages.length - index - 1] as Map<String, dynamic>;
            final mine = message['senderId'] == controller.memberId;
            final kind = message['kind'] as String? ?? 'text';
            return Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Card(
                  color: mine
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: kind == 'audio' && message['mediaId'] != null
                        ? _VoiceMessage(mediaId: message['mediaId'] as String)
                        : kind == 'sticker'
                            ? Text(message['text'] as String? ?? '',
                                style: const TextStyle(fontSize: 42))
                            : message['mediaId'] != null &&
                                    (message['mediaId'] as String).isNotEmpty
                                ? InkWell(
                                    onTap: () => _showAttachment(message),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(kind == 'image'
                                              ? Icons.image
                                              : kind == 'video'
                                                  ? Icons.videocam
                                                  : kind == 'audio'
                                                      ? Icons.mic
                                                      : Icons.attach_file),
                                          const SizedBox(width: 8),
                                          Flexible(
                                              child: Text(message['fileName']
                                                      as String? ??
                                                  'Attachment')),
                                        ]))
                                : Text(message['text'] as String? ?? ''),
                  )),
            );
          },
        )),
        SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(children: [
                  IconButton(
                      onPressed: sending ? null : _attach,
                      tooltip: 'Attach file',
                      icon: const Icon(Icons.add_circle_outline)),
                  IconButton(
                      onPressed: _pickSticker,
                      tooltip: 'Stickers and emoji',
                      icon: const Icon(Icons.emoji_emotions_outlined)),
                  IconButton(
                      onPressed: sending ? null : _toggleRecording,
                      tooltip: recording
                          ? 'Stop and send recording'
                          : 'Record voice message',
                      icon:
                          Icon(recording ? Icons.stop_circle : Icons.mic_none)),
                  Expanded(
                      child: TextField(
                          controller: input,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                              hintText: 'Message your friend'))),
                  IconButton(
                      onPressed:
                          sending ? null : () => _send('text', input.text),
                      tooltip: 'Send',
                      icon: const Icon(Icons.send_rounded)),
                ]))),
      ]),
    );
  }

  Future<void> _showAttachment(Map<String, dynamic> message) async {
    final api = _ChatApi(context.read<MusicController>());
    try {
      final bytes = await api.download(message['mediaId'] as String);
      if (!mounted) return;
      if (message['kind'] == 'image') {
        showDialog<void>(
            context: context,
            builder: (_) =>
                Dialog(child: Image.memory(bytes, fit: BoxFit.contain)));
      } else {
        final dir = await getTemporaryDirectory();
        final name = (message['fileName'] as String? ?? 'attachment')
            .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final file = File('${dir.path}/$name');
        await file.writeAsBytes(bytes, flush: true);
        await OpenFile.open(file.path);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _VoiceMessage extends StatefulWidget {
  const _VoiceMessage({required this.mediaId});
  final String mediaId;

  @override
  State<_VoiceMessage> createState() => _VoiceMessageState();
}

class _VoiceMessageState extends State<_VoiceMessage> {
  final AudioPlayer player = AudioPlayer();
  File? temporaryFile;
  bool loading = false;

  @override
  void dispose() {
    player.dispose();
    temporaryFile?.delete().ignore();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (player.playing) {
        await player.pause();
        return;
      }
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      if (temporaryFile == null) {
        setState(() => loading = true);
        final bytes = await _ChatApi(context.read<MusicController>())
            .download(widget.mediaId);
        final dir = await getTemporaryDirectory();
        temporaryFile = File('${dir.path}/chat-${widget.mediaId}.m4a');
        await temporaryFile!.writeAsBytes(bytes, flush: true);
        await player.setFilePath(temporaryFile!.path);
      }
      if (mounted) setState(() => loading = false);
      await player.play();
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not play voice message: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                  onPressed: loading ? null : _toggle,
                  icon: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(player.playing
                          ? Icons.pause_circle
                          : Icons.play_circle)),
              const Text('Voice message'),
            ],
          ));
}

const _chatAlerts = MethodChannel('telugu_tunes/chat_alerts');
bool _outboxFlushing = false;
bool _alertPolling = false;
bool _alertsGranted = false;

Future<void> requestChatAlertPermission(MusicController controller) async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    _alertsGranted =
        await _chatAlerts.invokeMethod<bool>('requestPermission') ?? false;
    if (_alertsGranted) await pollChatAlerts(controller);
  } catch (_) {}
}

Future<void> pollChatAlerts(MusicController controller,
    {List? friendsResult}) async {
  if (!_alertsGranted || !controller.isAuthenticated || _alertPolling) return;
  _alertPolling = true;
  try {
    final friends =
        friendsResult ?? await _ChatApi(controller).get('/friends') as List;
    final prefs = await SharedPreferences.getInstance();
    for (final entry in friends) {
      final friend = entry as Map<String, dynamic>;
      if (friend['status'] != 'accepted' ||
          (friend['unreadCount'] as num? ?? 0) <= 0) continue;
      final message = friend['lastMessage'] as Map<String, dynamic>?;
      if (message == null || message['senderId'] == controller.memberId)
        continue;
      final peer = friend['person'] as Map<String, dynamic>;
      final key = 'last_chat_alert_${controller.memberId}_${peer['id']}';
      final id = message['id'] as String? ?? '';
      if (id.isEmpty || prefs.getString(key) == id) continue;
      await _chatAlerts.invokeMethod<void>('show', {
        'id': (peer['id'] as String).hashCode,
        'title': peer['name'] as String? ?? 'New message',
        'body': _messagePreview(message, mine: false),
      });
      await prefs.setString(key, id);
    }
  } catch (_) {
    // The next poll will retry after a connection failure.
  } finally {
    _alertPolling = false;
  }
}

/// Retries messages from any app page while a signed-in session is active.
Future<void> flushChatQueue(MusicController controller) async {
  if (!controller.isAuthenticated || _outboxFlushing) return;
  _outboxFlushing = true;
  try {
    final api = _ChatApi(controller);
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_queue_${api.memberId}';
    final queued = (jsonDecode(prefs.getString(key) ?? '[]') as List)
        .cast<Map<String, dynamic>>();
    final remaining = <Map<String, dynamic>>[];
    for (final item in queued) {
      try {
        if ((item['localPath'] as String? ?? '').isNotEmpty) {
          final file = File(item['localPath'] as String);
          final uploaded = await api.upload(
              item['fileName'] as String, await file.readAsBytes());
          item['mediaId'] = uploaded['id'];
          item.remove('localPath');
          await file.delete();
        }
        await api.post('/${item['peerId']}', item);
      } catch (_) {
        remaining.add(item);
      }
    }
    final latest = (jsonDecode(prefs.getString(key) ?? '[]') as List)
        .cast<Map<String, dynamic>>();
    final startedIds = queued.map((item) => item['clientId']).toSet();
    remaining
        .addAll(latest.where((item) => !startedIds.contains(item['clientId'])));
    await prefs.setString(key, jsonEncode(remaining));
  } catch (_) {
    // Keep queued messages intact if local storage is temporarily unavailable.
  } finally {
    _outboxFlushing = false;
  }
}

class _ChatApi {
  _ChatApi(MusicController controller)
      : base = '${controller.apiBaseUrl}/messages',
        token = controller.authToken,
        memberId = controller.memberId;
  final String base;
  final String token;
  final String memberId;
  Map<String, String> get headers => {'Authorization': 'Bearer $token'};

  Future<dynamic> get(String path) async {
    final response = await http.get(Uri.parse('$base$path'), headers: headers);
    return _decode(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$base$path'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body));
    return _decode(response);
  }

  Future<Map<String, dynamic>> upload(String name, Uint8List bytes) async {
    final request = http.MultipartRequest('POST', Uri.parse('$base/media'))
      ..headers.addAll(headers)
      ..files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: name, contentType: MediaType.parse(_mimeType(name))));
    return _decode(await http.Response.fromStream(await request.send()))
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadAvatar(
      String name, Uint8List bytes) async {
    final request = http.MultipartRequest('POST', Uri.parse('$base/avatar'))
      ..headers.addAll(headers)
      ..files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: name, contentType: MediaType.parse(_mimeType(name))));
    return _decode(await http.Response.fromStream(await request.send()))
        as Map<String, dynamic>;
  }

  Future<Uint8List> download(String id) async {
    final response =
        await http.get(Uri.parse('$base/media/$id'), headers: headers);
    if (response.statusCode >= 300)
      throw StateError('Attachment could not be opened.');
    return response.bodyBytes;
  }

  String _mimeType(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      _ => 'application/octet-stream',
    };
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) return null;
      return jsonDecode(response.body);
    }
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw _ChatHttpException(
          response.statusCode, body['message'] as String? ?? 'Request failed.');
    } catch (e) {
      if (e is _ChatHttpException) rethrow;
      throw _ChatHttpException(response.statusCode, 'Request failed.');
    }
  }
}

class _ChatHttpException implements Exception {
  const _ChatHttpException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}
