import 'dart:async';

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
  List<_SongMetadataDraft> _songDrafts = [];
  int _activeSongIndex = 0;
  String _color = '7C4DFF';
  String _metadataNotice = '';
  String _metadataSource = '';
  String _sourceUrl = '';
  bool _submitting = false;
  bool _askingAi = false;
  Timer? _uploadStatusTimer;
  int _uploadElapsedSeconds = 0;
  int _uploadFileIndex = 0;
  String _uploadStage = '';

  @override
  void dispose() {
    _uploadStatusTimer?.cancel();
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
    if (source == ImportSource.deviceFolder) {
      await _requestAlbumAndPickFiles();
      return;
    }
    if (source == ImportSource.deviceFile) {
      _album.clear();
      await _pickAudio(allowMultiple: false);
      return;
    }
    setState(() => _selected = source);
  }

  Future<void> _requestAlbumAndPickFiles() async {
    final input = TextEditingController(text: _album.text);
    final albumName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Name this album'),
        content: TextField(
          controller: input,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Album / movie name',
            hintText: 'Enter once for all selected songs',
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(dialogContext, value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (input.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, input.text.trim());
              }
            },
            child: const Text('Choose songs'),
          ),
        ],
      ),
    );
    _disposeAfterRouteTransition(input);
    if (albumName == null || albumName.isEmpty || !mounted) return;
    _album.text = albumName;
    await _pickAudio(allowMultiple: true);
  }

  Future<void> _editAlbumName() async {
    final input = TextEditingController(text: _album.text);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit album name'),
        content: TextField(
          controller: input,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Album / movie name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (input.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, input.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    _disposeAfterRouteTransition(input);
    if (value != null && mounted) setState(() => _album.text = value);
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
              '$details\n\nThese files exceed 5 MB. Telugu Tunes will convert them to a browser-safe MP3 and guarantee each stored file is no larger than 5 MB. Continue?',
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
      final drafts = files
          .map((file) => _SongMetadataDraft(title: _nameFromFile(file.name)))
          .toList();
      setState(() {
        _audioFiles = files;
        _songDrafts = drafts;
        _activeSongIndex = 0;
      });
      await _prefillFromCatalog(files);
      _loadDraft(0);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _prefillFromCatalog(List<PlatformFile> files) async {
    if (!context.read<MusicController>().remoteMode) return;
    var matched = 0;
    var youtubeFallbacks = 0;
    final drafts = List<_SongMetadataDraft>.from(_songDrafts);
    for (var index = 0; index < files.length; index++) {
      try {
        final metadata = await context
            .read<MusicController>()
            .matchMetadataCatalog(files[index].name);
        if (metadata != null) {
          matched++;
          drafts[index] = _SongMetadataDraft(
            title: metadata.songName.isEmpty
                ? drafts[index].title
                : metadata.songName,
            artist: metadata.primaryArtist,
            singers: metadata.singers,
            musicDirector: metadata.musicDirector,
            genre: metadata.genre,
            metadataSource: 'Excel metadata catalog',
            metadataNotice: 'Matched ${files[index].name}',
          );
          continue;
        }

        final fallback = await context
            .read<MusicController>()
            .suggestYouTubeMetadata(_nameFromFile(files[index].name));
        final hasFallback = fallback.artist.isNotEmpty ||
            fallback.album.isNotEmpty ||
            fallback.singers.isNotEmpty;
        if (!hasFallback) continue;
        youtubeFallbacks++;
        drafts[index] = _SongMetadataDraft(
          title: fallback.title.isEmpty ? drafts[index].title : fallback.title,
          artist: fallback.artist,
          singers: fallback.singers,
          musicDirector: fallback.musicDirector,
          genre: fallback.genre,
          artworkUrl: fallback.artworkCandidates.isEmpty
              ? fallback.thumbnailUrl
              : fallback.artworkCandidates.first.imageUrl,
          color: fallback.color,
          sourceUrl: fallback.sourceUrl,
          metadataSource: 'YouTube fallback',
          metadataNotice: 'No Excel match; review the fetched details.',
        );
      } catch (_) {
        // An unmatched or temporarily unavailable catalog must never block upload.
      }
    }
    if (!mounted) return;
    setState(() {
      _songDrafts = drafts;
      if (matched > 0 || youtubeFallbacks > 0) {
        _metadataSource = 'Excel first';
        _metadataNotice = '$matched Excel matches, '
            '$youtubeFallbacks YouTube fallbacks for ${files.length} songs.';
      }
    });
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
      // The administrator may correct a noisy download filename before
      // searching. Always prefer the current title field; use the original
      // filename only when no title has been entered.
      final editedTitle = _title.text.trim();
      final catalogQuery = editedTitle.isNotEmpty
          ? editedTitle
          : (_audioFiles.isNotEmpty &&
                  _activeSongIndex >= 0 &&
                  _activeSongIndex < _audioFiles.length
              ? _audioFiles[_activeSongIndex].name
              : query);
      final catalog = await context
          .read<MusicController>()
          .matchMetadataCatalog(catalogQuery);
      if (catalog != null) {
        if (!mounted) return;
        setState(() {
          _title.text =
              catalog.songName.isEmpty ? _title.text : catalog.songName;
          _artist.text = catalog.primaryArtist;
          _album.text = catalog.album;
          _singers.text = catalog.singers;
          _musicDirector.text = catalog.musicDirector;
          _genre.text = catalog.genre;
          _metadataSource = 'Excel metadata catalog';
          _metadataNotice =
              'Matched the uploaded catalog. YouTube was not used.';
        });
        _saveActiveDraft();
        return;
      }

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
        _metadataSource = '${result.source} fallback';
        _metadataNotice = 'No Excel catalog match. ${result.notice}';
      });
      _saveActiveDraft();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _askingAi = false);
    }
  }

  Future<void> _upload() async {
    if (_audioFiles.isEmpty) return;
    _saveActiveDraft();
    final incomplete = _songDrafts.indexWhere((draft) => draft.title.isEmpty);
    if (incomplete >= 0) {
      _goToSong(incomplete);
      _showMessage('Enter a title for song ${incomplete + 1}.');
      return;
    }
    _startUploadStatus();
    try {
      final controller = context.read<MusicController>();
      ImportReceipt? receipt;
      final receipts = <ImportReceipt>[];
      for (var index = 0; index < _audioFiles.length; index++) {
        final file = _audioFiles[index];
        final draft = _songDrafts[index];
        if (mounted) {
          setState(() {
            _uploadFileIndex = index;
            _uploadElapsedSeconds = 0;
            _uploadStage = 'Uploading ${file.name} to the server…';
          });
        }
        receipt = await controller.uploadAudio(
          file.name,
          file.bytes!,
          title: draft.title,
          artist: draft.artist,
          album: _album.text.trim(),
          color: draft.color,
          singers: draft.singers,
          musicDirector: draft.musicDirector,
          genre: draft.genre,
          artworkUrl: draft.artworkUrl,
          sourceUrl: draft.sourceUrl,
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
      _stopUploadStatus();
    }
  }

  void _saveActiveDraft() {
    if (_songDrafts.isEmpty || _activeSongIndex >= _songDrafts.length) return;
    _songDrafts[_activeSongIndex] = _SongMetadataDraft(
      title: _title.text.trim(),
      artist: _artist.text.trim(),
      singers: _singers.text.trim(),
      musicDirector: _musicDirector.text.trim(),
      genre: _genre.text.trim(),
      youtubeUrl: _youtubeUrl.text.trim(),
      artworkUrl: _artworkUrl.text.trim(),
      color: _color,
      metadataNotice: _metadataNotice,
      metadataSource: _metadataSource,
      sourceUrl: _sourceUrl,
    );
  }

  void _loadDraft(int index) {
    final draft = _songDrafts[index];
    _title.text = draft.title;
    _artist.text = draft.artist;
    _singers.text = draft.singers;
    _musicDirector.text = draft.musicDirector;
    _genre.text = draft.genre;
    _youtubeUrl.text = draft.youtubeUrl;
    _artworkUrl.text = draft.artworkUrl;
    _color = draft.color;
    _metadataNotice = draft.metadataNotice.isEmpty
        ? 'Review this song’s details. Each file keeps its own metadata.'
        : draft.metadataNotice;
    _metadataSource = draft.metadataSource;
    _sourceUrl = draft.sourceUrl;
  }

  void _goToSong(int index) {
    if (index < 0 || index >= _songDrafts.length || _submitting) return;
    _saveActiveDraft();
    setState(() {
      _activeSongIndex = index;
      _loadDraft(index);
    });
  }

  void _handleSongSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -180 && _activeSongIndex < _songDrafts.length - 1) {
      _goToSong(_activeSongIndex + 1);
    } else if (velocity > 180 && _activeSongIndex > 0) {
      _goToSong(_activeSongIndex - 1);
    }
  }

  void _startUploadStatus() {
    _uploadStatusTimer?.cancel();
    setState(() {
      _submitting = true;
      _uploadElapsedSeconds = 0;
      _uploadFileIndex = 0;
      _uploadStage = 'Uploading ${_audioFiles.first.name} to the server…';
    });
    _uploadStatusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_submitting) return;
      setState(() {
        _uploadElapsedSeconds++;
        final file = _audioFiles[_uploadFileIndex];
        final bytes = file.bytes?.length ?? file.size;
        if (_uploadElapsedSeconds >= 12 && bytes > _maximumStoredAudioBytes) {
          _uploadStage = 'Compressing to MP3 below 5 MB, then saving to OCI…';
        } else if (_uploadElapsedSeconds >= 12) {
          _uploadStage = 'Saving the song to OCI storage…';
        }
      });
    });
  }

  void _stopUploadStatus() {
    _uploadStatusTimer?.cancel();
    _uploadStatusTimer = null;
    if (mounted) {
      setState(() {
        _submitting = false;
        _uploadElapsedSeconds = 0;
        _uploadStage = '';
      });
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

  void _disposeAfterRouteTransition(TextEditingController controller) {
    Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
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

  Widget _metadataForm(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: _audioFiles.length > 1 ? _handleSongSwipe : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_audioFiles.length > 1 ? 'Build album' : 'Review song details',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              _audioFiles.length == 1
                  ? _audioFiles.first.name
                  : 'Song ${_activeSongIndex + 1} of ${_audioFiles.length} • ${_audioFiles[_activeSongIndex].name}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_audioFiles.length > 1) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (_activeSongIndex + 1) / _audioFiles.length,
                borderRadius: BorderRadius.circular(20),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.album_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Album',
                              style: Theme.of(context).textTheme.labelMedium),
                          Text(_album.text,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 16)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _submitting ? null : _editAlbumName,
                      tooltip: 'Edit album name',
                      icon: const Icon(Icons.edit_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Swipe left for next song • swipe right to go back',
                  style: Theme.of(context).textTheme.labelMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
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
                helperText:
                    'You can replace the suggested cover before upload.',
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
            if (_audioFiles.length > 1)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _activeSongIndex == 0 || _submitting
                          ? null
                          : () => _goToSong(_activeSongIndex - 1),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _activeSongIndex < _audioFiles.length - 1
                        ? FilledButton.icon(
                            onPressed: _submitting
                                ? null
                                : () => _goToSong(_activeSongIndex + 1),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('Save & next'),
                          )
                        : FilledButton.icon(
                            onPressed: _submitting ? null : _upload,
                            icon: _submitting
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.cloud_upload_rounded),
                            label:
                                Text(_submitting ? _uploadStage : 'Save album'),
                          ),
                  ),
                ],
              )
            else
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
                      _submitting ? _uploadStage : 'Upload to private library'),
                ),
              ),
            if (_submitting) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                semanticsLabel: _uploadStage,
              ),
              const SizedBox(height: 6),
              Text(
                '${_audioFiles.length > 1 ? 'File ${_uploadFileIndex + 1} of ${_audioFiles.length} • ' : ''}${_uploadElapsedSeconds}s elapsed. Keep this window open.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => setState(() {
                        _audioFiles = [];
                        _songDrafts = [];
                        _activeSongIndex = 0;
                      }),
              child: const Text('Choose different files'),
            ),
          ],
        ),
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
            if (_audioFiles.length == 1)
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

class _SongMetadataDraft {
  const _SongMetadataDraft({
    required this.title,
    this.artist = '',
    this.singers = '',
    this.musicDirector = '',
    this.genre = '',
    this.youtubeUrl = '',
    this.artworkUrl = '',
    this.color = '7C4DFF',
    this.metadataNotice = '',
    this.metadataSource = '',
    this.sourceUrl = '',
  });

  final String title;
  final String artist;
  final String singers;
  final String musicDirector;
  final String genre;
  final String youtubeUrl;
  final String artworkUrl;
  final String color;
  final String metadataNotice;
  final String metadataSource;
  final String sourceUrl;
}

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
