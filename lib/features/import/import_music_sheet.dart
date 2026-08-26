import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/music_models.dart';
import '../../state/music_controller.dart';
import '../shared/widgets.dart';

const _maximumStoredAudioBytes = 5000000;

void showImportMusicSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ImportMusicSheet(),
  );
}

class _ImportMusicSheet extends StatefulWidget {
  const _ImportMusicSheet();

  @override
  State<_ImportMusicSheet> createState() => _ImportMusicSheetState();
}

class _ImportMusicSheetState extends State<_ImportMusicSheet> {
  final _url = TextEditingController();
  final _title = TextEditingController();
  final _artist = TextEditingController();
  final _album = TextEditingController();
  final _singers = TextEditingController();
  final _musicDirector = TextEditingController();
  final _genre = TextEditingController();
  final _youtubeUrl = TextEditingController();
  final _artworkUrl = TextEditingController();
  ImportSource? _selected;
  List<PlatformFile> _audioFiles = [];
  String _color = '7C4DFF';
  String _metadataNotice = '';
  String _metadataSource = '';
  String _sourceUrl = '';
  bool _submitting = false;
  bool _askingAi = false;

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    _artist.dispose();
    _album.dispose();
    _singers.dispose();
    _musicDirector.dispose();
    _genre.dispose();
    _youtubeUrl.dispose();
    _artworkUrl.dispose();
    super.dispose();
  }

  Future<void> _select(ImportSource source) async {
    if (source == ImportSource.deviceFile ||
        source == ImportSource.deviceFolder) {
      await _pickAudio(allowMultiple: source == ImportSource.deviceFolder);
      return;
    }
    setState(() => _selected = source);
  }

  Future<void> _pickAudio({required bool allowMultiple}) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: allowMultiple,
        withData: true,
      );
      if (result == null) return;
      final files = result.files.where((file) => file.bytes != null).toList();
      if (files.isEmpty) {
        throw StateError(
            'The selected file could not be read. Please try again.');
      }
      final oversized = files
          .where((file) =>
              (file.bytes?.length ?? file.size) > _maximumStoredAudioBytes)
          .toList();
      if (oversized.isNotEmpty) {
        if (!mounted) return;
        final details = oversized
            .map((file) =>
                '${file.name} (${_megabytes(file.bytes?.length ?? file.size)})')
            .join('\n');
        final approved = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Compress oversized audio?'),
            content: Text(
              '$details\n\nThese files exceed 5 MB. Telugu Tunes will convert them to M4A and guarantee each stored file is no larger than 5 MB. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Compress and add'),
              ),
            ],
          ),
        );
        if (approved != true) return;
      }
      final firstName = _nameFromFile(files.first.name);
      setState(() {
        _audioFiles = files;
        _title.text = firstName;
        _artist.clear();
        _album.text = files.length > 1 ? 'Imported album' : '';
        _singers.clear();
        _musicDirector.clear();
        _genre.clear();
        _color = '7C4DFF';
        _metadataSource = '';
        _artworkUrl.clear();
        _sourceUrl = '';
        _metadataNotice =
            'Review the details below. They will be saved with the uploaded audio.';
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _askAi() async {
    final query = _youtubeUrl.text.trim().isNotEmpty
        ? _youtubeUrl.text.trim()
        : _title.text.trim().isNotEmpty
            ? _title.text.trim()
            : (_audioFiles.isEmpty
                ? ''
                : _nameFromFile(_audioFiles.first.name));
    if (query.isEmpty) return;
    setState(() => _askingAi = true);
    try {
      final result =
          await context.read<MusicController>().suggestMetadata(query);
      if (!mounted) return;
      final currentArtwork = _artworkUrl.text.trim();
      final selectedCover = result.artworkCandidates.isEmpty
          ? null
          : await showArtworkPicker(context, result.artworkCandidates);
      if (!mounted) return;
      setState(() {
        // A YouTube video title is often promotional text, so never replace the member's title.
        _artist.text = result.artist;
        _album.text = result.album;
        _singers.text = result.singers;
        _musicDirector.text = result.musicDirector;
        _genre.text = result.genre;
        _color = result.color;
        _artworkUrl.text = selectedCover?.imageUrl ?? currentArtwork;
        _sourceUrl = result.sourceUrl;
        _metadataSource = result.source;
        _metadataNotice = result.notice;
      });
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _askingAi = false);
    }
  }

  Future<void> _upload() async {
    if (_audioFiles.isEmpty) return;
    if (_title.text.trim().isEmpty) {
      _showMessage('Enter a title before uploading.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final controller = context.read<MusicController>();
      ImportReceipt? receipt;
      final receipts = <ImportReceipt>[];
      for (var index = 0; index < _audioFiles.length; index++) {
        final file = _audioFiles[index];
        receipt = await controller.uploadAudio(
          file.name,
          file.bytes!,
          title: index == 0 ? _title.text.trim() : _nameFromFile(file.name),
          artist: _artist.text.trim(),
          album: _album.text.trim(),
          color: _color,
          singers: _singers.text.trim(),
          musicDirector: _musicDirector.text.trim(),
          genre: _genre.text.trim(),
          artworkUrl: _artworkUrl.text.trim(),
          sourceUrl: _sourceUrl,
        );
        receipts.add(receipt);
      }
      if (!mounted) return;
      final compressed = receipts.where((item) => item.compressed).map((item) =>
          '${item.fileName}: ${_megabytes(item.originalBytes)} → ${_megabytes(item.storedBytes)}');
      final message = compressed.isEmpty
          ? receipt!.message
          : 'Upload complete. Compressed size:\n${compressed.join('\n')}';
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _saveReference() async {
    final value = _url.text.trim();
    if (value.isEmpty || _selected == null) {
      _showMessage('Enter a valid link first.');
      return;
    }
    try {
      setState(() => _submitting = true);
      final receipt = await context
          .read<MusicController>()
          .addImport(ImportRequest(source: _selected!, value: value));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(receipt.message)));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(Object error) =>
      _showMessage(error.toString().replaceFirst('Bad state: ', ''));

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _nameFromFile(String fileName) => fileName
      .replaceFirst(RegExp(r'\.[a-zA-Z0-9]{2,5}$'), '')
      .replaceAll(RegExp('[_-]+'), ' ')
      .trim();

  String get _linkLabel => switch (_selected) {
        ImportSource.directUrl => 'Licensed audio URL',
        ImportSource.metadataLink => 'YouTube or Spotify link',
        ImportSource.googleDrive => 'Google Drive file or folder link',
        _ => 'Music link',
      };

  String get _linkHint => _selected == ImportSource.googleDrive
      ? 'https://drive.google.com/...'
      : 'https://';

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .88),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
            child: _audioFiles.isNotEmpty
                ? _metadataForm(context)
                : _sourcePicker(context),
          ),
        ),
      );

  Widget _sourcePicker(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add music',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
              'Audio is stored in the private Drive folder. Links only save a private import request.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 18),
          if (_selected != null)
            _referenceForm(context)
          else ...[
            _ImportOption(
                icon: Icons.audio_file_rounded,
                title: 'Device file',
                subtitle: 'Upload one audio file',
                source: ImportSource.deviceFile,
                onTap: _select),
            _ImportOption(
                icon: Icons.folder_copy_rounded,
                title: 'Album files',
                subtitle: 'Upload several audio files',
                source: ImportSource.deviceFolder,
                onTap: _select),
            _ImportOption(
                icon: Icons.add_to_drive_rounded,
                title: 'Google Drive link',
                subtitle: 'Save a Drive file or folder reference',
                source: ImportSource.googleDrive,
                onTap: _select),
            _ImportOption(
                icon: Icons.language_rounded,
                title: 'Direct URL',
                subtitle: 'Add a licensed audio URL',
                source: ImportSource.directUrl,
                onTap: _select),
            _ImportOption(
                icon: Icons.auto_awesome_rounded,
                title: 'YouTube / Spotify link',
                subtitle: 'Import metadata only — no audio download',
                source: ImportSource.metadataLink,
                onTap: _select),
          ],
        ],
      );

  Widget _referenceForm(BuildContext context) => Column(
        children: [
          TextField(
            controller: _url,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
                labelText: _linkLabel,
                hintText: _linkHint,
                prefixIcon: const Icon(Icons.link_rounded)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _saveReference,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_rounded),
              label: Text(_submitting ? 'Saving…' : 'Save import request'),
            ),
          ),
          TextButton(
              onPressed: () => setState(() => _selected = null),
              child: const Text('Back')),
        ],
      );

  Widget _metadataForm(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review song details',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            _audioFiles.length == 1
                ? _audioFiles.first.name
                : '${_audioFiles.length} files selected — album and artist apply to all.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Song title')),
          const SizedBox(height: 10),
          _metadataFields(context),
          const SizedBox(height: 10),
          TextField(
            controller: _youtubeUrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'YouTube song URL (optional, best match)',
              hintText: 'https://www.youtube.com/watch?v=...',
              prefixIcon: Icon(Icons.smart_display_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _artworkUrl,
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Artwork URL (optional)',
              helperText: 'You can replace the suggested cover before upload.',
              prefixIcon: Icon(Icons.image_outlined),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _askingAi ? null : _askAi,
            icon: _askingAi
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(_askingAi
                ? 'Finding details…'
                : 'Find details and choose cover'),
          ),
          if (_artworkUrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _metadataPreview(context),
          ],
          if (_metadataNotice.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _metadataSource.isEmpty
                  ? _metadataNotice
                  : 'Source: $_metadataSource — $_metadataNotice',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Song details only label the upload. They do not replace the selected MP3, so choose audio that matches the song.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _upload,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(
                  _submitting ? 'Uploading…' : 'Upload to private library'),
            ),
          ),
          TextButton(
            onPressed:
                _submitting ? null : () => setState(() => _audioFiles = []),
            child: const Text('Choose different files'),
          ),
        ],
      );

  Widget _metadataFields(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final fields = [
            TextField(
              controller: _artist,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Primary artist'),
            ),
            TextField(
              controller: _album,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Album / movie',
                helperText:
                    'If it is not found automatically, enter the movie name.',
              ),
            ),
            TextField(
              controller: _singers,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Singer(s)'),
            ),
            TextField(
              controller: _musicDirector,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Music director'),
            ),
            TextField(
              controller: _genre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Genre'),
            ),
          ];
          if (compact) {
            return Column(
              children: [
                for (final field in fields) ...[
                  field,
                  const SizedBox(height: 10)
                ],
              ],
            );
          }
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final field in fields)
                SizedBox(width: (constraints.maxWidth - 10) / 2, child: field),
            ],
          );
        },
      );

  Widget _metadataPreview(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Artwork(
              color: _color,
              label: _album.text.trim().isEmpty
                  ? _title.text.trim()
                  : _album.text.trim(),
              imageUrl: _artworkUrl.text.trim(),
              size: 72,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Square catalog artwork is preferred. YouTube thumbnails are not used. The image is linked, not copied into storage.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
}

String _megabytes(int bytes) => '${(bytes / 1000000).toStringAsFixed(2)} MB';

class _ImportOption extends StatelessWidget {
  const _ImportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.source,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ImportSource source;
  final ValueChanged<ImportSource> onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(icon)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => onTap(source),
        ),
      );
}
