import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/music_models.dart';
import '../../state/music_controller.dart';

class UserStatisticsScreen extends StatefulWidget {
  const UserStatisticsScreen({super.key, required this.member});
  final AdminMember member;

  @override
  State<UserStatisticsScreen> createState() => _UserStatisticsScreenState();
}

class _UserStatisticsScreenState extends State<UserStatisticsScreen> {
  int _days = 30;
  MemberListeningStatistics? _statistics;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _statistics = null;
      _error = null;
    });
    try {
      final result = await context
          .read<MusicController>()
          .getMemberStatistics(widget.member.id, days: _days);
      if (mounted) setState(() => _statistics = result);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('${widget.member.displayName} statistics')),
        body: _statistics == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: _body(_statistics!),
              ),
      );

  Widget _body(MemberListeningStatistics statistics) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7 days')),
              ButtonSegment(value: 30, label: Text('30 days')),
              ButtonSegment(value: 90, label: Text('90 days')),
            ],
            selected: {_days},
            onSelectionChanged: (value) {
              _days = value.first;
              _load();
            },
          ),
          const SizedBox(height: 16),
          _SummaryCard(statistics: statistics),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Daily listening hours',
            subtitle:
                'Listening while the app was active and music was playing',
            child: SizedBox(
              height: 210,
              child: CustomPaint(
                painter: _DailyListeningChart(
                    statistics.daily, Theme.of(context).colorScheme),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _BreakdownCard(
              title: 'Categories listened to', values: statistics.categories),
          const SizedBox(height: 16),
          _BreakdownCard(
              title: 'Where listening started', values: statistics.sources),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Listening order',
            subtitle:
                'Newest first • album, personal and recommended sources are labelled',
            child: statistics.playbackOrder.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: Text('No playback history yet.')),
                  )
                : Column(
                    children: [
                      for (var i = 0;
                          i < math.min(100, statistics.playbackOrder.length);
                          i++)
                        _HistoryTile(
                            index: statistics.playbackOrder.length - i,
                            item: statistics.playbackOrder[i]),
                    ],
                  ),
          ),
        ],
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.statistics});
  final MemberListeningStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final activeDays = statistics.daily.where((day) => day.seconds > 0).length;
    final average = activeDays == 0 ? 0 : statistics.totalSeconds ~/ activeDays;
    final favorite = _largest(statistics.sources);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 28,
          runSpacing: 18,
          children: [
            _Metric(
                label: 'Total listening',
                value: _duration(statistics.totalSeconds)),
            _Metric(label: 'Active days', value: '$activeDays'),
            _Metric(label: 'Daily average', value: _duration(average)),
            _Metric(label: 'Usually listens from', value: favorite),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          Text(label),
        ]),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 18),
            child,
          ]),
        ),
      );
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.title, required this.values});
  final String title;
  final Map<String, int> values;
  @override
  Widget build(BuildContext context) {
    final sorted = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = values.values.fold<int>(0, (sum, value) => sum + value);
    return _SectionCard(
      title: title,
      subtitle:
          total == 0 ? 'No listening recorded yet' : 'Share of listening time',
      child: Column(children: [
        for (final entry in sorted) ...[
          Row(children: [
            Expanded(child: Text(entry.key, overflow: TextOverflow.ellipsis)),
            Text(
                '${total == 0 ? 0 : entry.value * 100 ~/ total}% • ${_duration(entry.value)}'),
          ]),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: total == 0 ? 0 : entry.value / total),
          const SizedBox(height: 14),
        ],
      ]),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.index, required this.item});
  final int index;
  final PlaybackHistoryEntry item;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(child: Text('$index')),
        title: Text(item.title),
        subtitle: Text(
            '${item.artist} • ${item.album}\n${item.source} • ${item.genre}'),
        isThreeLine: true,
        trailing: Text(_time(item.startedAt)),
      );
}

class _DailyListeningChart extends CustomPainter {
  _DailyListeningChart(this.points, this.colors);
  final List<DailyListeningPoint> points;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final visible =
        points.length > 31 ? points.sublist(points.length - 31) : points;
    final maxSeconds = visible.fold<int>(
        1, (maxValue, point) => math.max(maxValue, point.seconds));
    final axis = Paint()..color = colors.outlineVariant;
    final bar = Paint()..color = colors.primary;
    const left = 38.0;
    const bottom = 28.0;
    final chartHeight = size.height - bottom - 8;
    canvas.drawLine(
        Offset(left, chartHeight), Offset(size.width, chartHeight), axis);
    if (visible.isEmpty) return;
    final slot = (size.width - left) / visible.length;
    for (var i = 0; i < visible.length; i++) {
      final height = chartHeight * visible[i].seconds / maxSeconds;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(left + i * slot + slot * .18, chartHeight - height,
                  math.max(2, slot * .64), height),
              const Radius.circular(4)),
          bar);
    }
    final text = TextPainter(textDirection: TextDirection.ltr);
    text.text = TextSpan(
        text: _duration(maxSeconds),
        style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant));
    text.layout();
    text.paint(canvas, const Offset(0, 2));
    text.text = TextSpan(
        text: '0h',
        style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant));
    text.layout();
    text.paint(canvas, Offset(8, chartHeight - 8));
    final labels = <int>{0, visible.length ~/ 2, visible.length - 1};
    for (final i in labels) {
      text.text = TextSpan(
          text: '${visible[i].date.day}/${visible[i].date.month}',
          style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant));
      text.layout();
      text.paint(canvas, Offset(left + i * slot, chartHeight + 7));
    }
  }

  @override
  bool shouldRepaint(covariant _DailyListeningChart oldDelegate) =>
      oldDelegate.points != points;
}

String _largest(Map<String, int> values) {
  if (values.isEmpty) return 'Not enough data';
  return values.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

String _duration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
}

String _time(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day}/${local.month} $hour:$minute';
}
