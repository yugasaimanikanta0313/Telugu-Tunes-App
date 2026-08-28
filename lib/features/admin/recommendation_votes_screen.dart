import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/music_models.dart';
import '../../state/music_controller.dart';
import '../shared/widgets.dart';

class RecommendationVotesScreen extends StatefulWidget {
  const RecommendationVotesScreen({super.key});
  @override
  State<RecommendationVotesScreen> createState() => _RecommendationVotesScreenState();
}

class _RecommendationVotesScreenState extends State<RecommendationVotesScreen> {
  List<RecommendationVoteSuggestion> items = const [];
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final result = await context.read<MusicController>().getRecommendationVotes();
      if (mounted) setState(() { items = result; loading = false; error = null; });
    } catch (value) {
      if (mounted) setState(() { loading = false; error = value.toString(); });
    }
  }

  Future<void> _review(RecommendationVoteSuggestion item, bool approve) async {
    await context.read<MusicController>().reviewRecommendationVote(item, approve);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          approve ? 'Song added to ${item.playlist.name}.' : 'Suggestion rejected.')));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Community playlist votes')),
    body: loading ? const Center(child: CircularProgressIndicator())
      : error != null ? Center(child: Text(error!))
      : items.isEmpty ? const Center(child: Text('No votes are waiting for review.'))
      : ListView.builder(
          padding: const EdgeInsets.all(16), itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
              ListTile(
                leading: Artwork(color: item.track.color, label: item.track.album,
                    imageUrl: item.track.artworkUrl, size: 56),
                title: Text(item.track.title),
                subtitle: Text('${item.track.artist}\nFor ${item.playlist.name} • ${item.playlist.subtype}\n${item.voteCount} vote${item.voteCount == 1 ? '' : 's'}'),
                isThreeLine: true,
              ),
              if (item.reasons.isNotEmpty)
                Align(alignment: Alignment.centerLeft,
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Reasons: ${item.reasons.join(' • ')}'))),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => _review(item, false), child: const Text('Reject')),
                const SizedBox(width: 8),
                FilledButton.icon(onPressed: () => _review(item, true),
                    icon: const Icon(Icons.playlist_add_check_rounded), child: const Text('Approve & add')),
              ]),
            ]));
          }),
  );
}
