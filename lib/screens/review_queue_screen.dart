import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/clinical_models.dart';
import '../services/clinical_service.dart';
import '../theme.dart';
import '../widgets/pressable.dart';
import 'note_review_screen.dart';

/// Workflow stage a note sits in — the clinician's mental model of "whose turn
/// is it". The Notes tab is filtered by this.
enum _Bucket { review, inProgress, completed }

/// How the (filtered) notes are organised in the list.
enum _GroupBy { stage, date, patient, recent }

/// The clinician's notes list. Filter by workflow stage (To review / In
/// progress / Done) and organise by Stage, Date, Patient or Recent — so it's
/// always clear what needs attention and easy to find a specific note.
class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  /// null = all stages; otherwise a single stage is shown.
  _Bucket? _filter;
  // Default to a day-by-day view (Today / Yesterday / …) so notes read the same
  // date-first way as the patient schedule.
  _GroupBy _group = _GroupBy.date;

  // --- Workflow bucketing ---

  _Bucket _bucketOf(VisitStatus s) {
    switch (s) {
      case VisitStatus.readyForReview:
      case VisitStatus.failed:
        return _Bucket.review;
      case VisitStatus.approved:
      case VisitStatus.syncedToEhr:
        return _Bucket.completed;
      default: // recording, pendingUpload, withScribe, changesRequested
        return _Bucket.inProgress;
    }
  }

  /// All real notes (excludes empty scheduled-visit shells, which the service
  /// already keeps out of the review queue).
  List<Visit> _allNotes(ClinicalService svc) =>
      [...svc.reviewQueue, ...svc.completed];

  List<Visit> _recentFirst(Iterable<Visit> v) =>
      [...v]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<ClinicalService>();
    final all = _allNotes(svc);

    final byBucket = <_Bucket, List<Visit>>{
      for (final b in _Bucket.values)
        b: all.where((v) => _bucketOf(v.status) == b).toList(),
    };

    // Apply the stage filter.
    final filtered = _filter == null ? all : byBucket[_filter]!;

    return Scaffold(
      backgroundColor: Clinic.backgroundLight,
      appBar: AppBar(
        title: const Text('Notes',
            style:
                TextStyle(fontWeight: FontWeight.bold, color: Clinic.brandNavy)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: svc.loading ? null : svc.refresh,
            icon: const Icon(Icons.refresh, color: Clinic.primary),
          ),
        ],
      ),
      body: Column(
        children: [
          _connectivityBar(svc),
          if (svc.loading) const LinearProgressIndicator(minHeight: 2),
          _controlRow(byBucket),
          Expanded(
            child: RefreshIndicator(
              onRefresh: svc.refresh,
              child: _list(context, filtered, all.isEmpty),
            ),
          ),
        ],
      ),
    );
  }

  // --- Filter chips + group-by (styled to match the patient list) ---

  Widget _controlRow(Map<_Bucket, List<Visit>> byBucket) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All', null, null),
                  _filterChip('To review', _Bucket.review,
                      byBucket[_Bucket.review]!.length),
                  _filterChip('In progress', _Bucket.inProgress,
                      byBucket[_Bucket.inProgress]!.length),
                  _filterChip('Done', _Bucket.completed,
                      byBucket[_Bucket.completed]!.length),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          _groupDropdown(),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _Bucket? bucket, int? count) {
    final selected = _filter == bucket;
    final accent = bucket == null ? Clinic.primary : _bucketColor(bucket);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = bucket),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? accent : Clinic.cardWhite,
            borderRadius: BorderRadius.circular(Clinic.rControl),
            border: Border.all(color: selected ? accent : Clinic.borderColor),
            boxShadow: Clinic.rowShadow,
          ),
          child: Row(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : Clinic.brandNavy)),
              if (count != null && count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.25)
                        : accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Clinic.rChip),
                  ),
                  child: Text('$count',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: selected ? Colors.white : accent)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Clinic.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Clinic.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sort, size: 16, color: Clinic.secondary),
          const SizedBox(width: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<_GroupBy>(
              value: _group,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down,
                  size: 18, color: Clinic.secondary),
              style: const TextStyle(
                  fontSize: 12,
                  color: Clinic.brandNavy,
                  fontWeight: FontWeight.w600),
              items: const [
                DropdownMenuItem(value: _GroupBy.date, child: Text('Date')),
                DropdownMenuItem(value: _GroupBy.stage, child: Text('Stage')),
                DropdownMenuItem(
                    value: _GroupBy.patient, child: Text('Patient')),
                DropdownMenuItem(value: _GroupBy.recent, child: Text('Recent')),
              ],
              onChanged: (v) => setState(() => _group = v ?? _group),
            ),
          ),
        ],
      ),
    );
  }

  // --- The list ---

  Widget _list(BuildContext context, List<Visit> filtered, bool allEmpty) {
    if (allEmpty) {
      return ListView(children: [
        const SizedBox(height: 90),
        _emptyState(Icons.fact_check_outlined, 'No notes yet',
            'Record a visit and the note will show up here for review.'),
      ]);
    }
    if (filtered.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 90),
        _emptyState(_bucketIcon(_filter!), 'Nothing here',
            _emptyHintFor(_filter!)),
      ]);
    }

    final children = <Widget>[];
    switch (_group) {
      case _GroupBy.stage:
        // Group by workflow stage, in priority order. When a single stage is
        // already selected, that's just one section.
        final buckets = _filter == null
            ? [_Bucket.review, _Bucket.inProgress, _Bucket.completed]
            : [_filter!];
        for (final b in buckets) {
          final items =
              _recentFirst(filtered.where((v) => _bucketOf(v.status) == b));
          if (items.isEmpty) continue;
          children.add(_groupHeader(_bucketLabel(b), items.length,
              _bucketColor(b)));
          children.addAll(items.map((v) => Pressable(child: _noteCard(context, v))));
          children.add(const SizedBox(height: 10));
        }
      case _GroupBy.date:
        _addGrouped(
          context,
          children,
          filtered,
          keyOf: (v) {
            final d = DateTime.fromMillisecondsSinceEpoch(v.createdAt);
            return DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
          },
          // Newest day first.
          compareKeys: (a, b) => (b as int).compareTo(a as int),
          labelOf: (k) => _dayLabel(
              DateTime.fromMillisecondsSinceEpoch(k as int)),
          dot: Clinic.primary,
        );
      case _GroupBy.patient:
        _addGrouped(
          context,
          children,
          filtered,
          keyOf: (v) =>
              v.patientName.isEmpty ? 'Unknown patient' : v.patientName,
          compareKeys: (a, b) => (a as String)
              .toLowerCase()
              .compareTo((b as String).toLowerCase()),
          labelOf: (k) => k as String,
          dot: Clinic.brandNavy,
        );
      case _GroupBy.recent:
        final items = _recentFirst(filtered);
        children.add(_groupHeader('All notes', items.length, Clinic.secondary));
        children.addAll(items.map((v) => Pressable(child: _noteCard(context, v))));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: children,
    );
  }

  /// Generic grouping: bucket [items] by [keyOf], order groups by [compareKeys],
  /// render a header per group (via [labelOf]) then its notes newest-first.
  void _addGrouped(
    BuildContext context,
    List<Widget> children,
    List<Visit> items, {
    required Object Function(Visit) keyOf,
    required int Function(Object, Object) compareKeys,
    required String Function(Object) labelOf,
    required Color dot,
  }) {
    final groups = <Object, List<Visit>>{};
    for (final v in items) {
      groups.putIfAbsent(keyOf(v), () => []).add(v);
    }
    final keys = groups.keys.toList()..sort(compareKeys);
    for (final k in keys) {
      final list = _recentFirst(groups[k]!);
      children.add(_groupHeader(labelOf(k), list.length, dot));
      children.addAll(list.map((v) => Pressable(child: _noteCard(context, v))));
      children.add(const SizedBox(height: 10));
    }
  }

  Widget _groupHeader(String label, int count, Color dot) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10, left: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Clinic.secondary.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8)),
          ),
          const SizedBox(width: 6),
          Text('($count)',
              style: TextStyle(
                  color: Clinic.secondary.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _noteCard(BuildContext context, Visit v) {
    final (label, color) = _statusStyle(v.status);
    final dt = DateTime.fromMillisecondsSinceEpoch(v.createdAt);
    final actionable = v.status == VisitStatus.readyForReview ||
        v.status == VisitStatus.failed;
    final bits = [
      DateFormat('MMM d, h:mm a').format(dt),
      if (v.durationMs > 0) _dur(v.durationMs),
      if (v.visitType.isNotEmpty) v.visitType,
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Clinic.cardWhite,
          borderRadius: BorderRadius.circular(Clinic.rCard),
          border: Border.all(
              color: actionable
                  ? color.withValues(alpha: 0.45)
                  : Clinic.borderColor),
          boxShadow: Clinic.rowShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => NoteReviewScreen(visitId: v.id))),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: color),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Clinic.surfaceLight,
                            child: Text(
                                v.patientName.isNotEmpty
                                    ? v.patientName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Clinic.brandNavy,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                    v.patientName.isEmpty
                                        ? 'Unknown patient'
                                        : v.patientName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Clinic.brandNavy,
                                        fontSize: 15)),
                                const SizedBox(height: 3),
                                Text(bits,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Clinic.secondary
                                            .withValues(alpha: 0.7),
                                        fontSize: 11)),
                                const SizedBox(height: 6),
                                _statusPill(label, color),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right,
                              size: 20,
                              color: Clinic.secondary.withValues(alpha: 0.4)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusPill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Clinic.rChip),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2)),
          ],
        ),
      );

  // --- Stage / status / date presentation ---

  Color _bucketColor(_Bucket b) => switch (b) {
        _Bucket.review => Clinic.primary, // your turn
        _Bucket.inProgress => Clinic.statusWaiting, // waiting on scribe
        _Bucket.completed => Clinic.statusDone, // done — filed navy
      };

  String _bucketLabel(_Bucket b) => switch (b) {
        _Bucket.review => 'To review',
        _Bucket.inProgress => 'In progress',
        _Bucket.completed => 'Completed',
      };

  IconData _bucketIcon(_Bucket b) => switch (b) {
        _Bucket.review => Icons.rate_review_outlined,
        _Bucket.inProgress => Icons.hourglass_empty,
        _Bucket.completed => Icons.check_circle_outline,
      };

  String _emptyHintFor(_Bucket b) => switch (b) {
        _Bucket.review => 'No notes are waiting on you right now.',
        _Bucket.inProgress => 'Nothing is being written by a scribe right now.',
        _Bucket.completed => 'Approved notes will collect here.',
      };

  /// Friendly day header: Today / Yesterday / Tomorrow / weekday + date.
  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    return DateFormat('EEEE, MMM d').format(d);
  }

  /// Per-status pill (label, colour) in the DOCVA language: electric blue =
  /// your turn / active, amber = waiting on the scribe, navy = filed & done,
  /// red = needs attention.
  (String, Color) _statusStyle(VisitStatus s) => switch (s) {
        VisitStatus.recording => ('Recording', Clinic.statusActive),
        VisitStatus.pendingUpload => ('Uploading', Clinic.statusWaiting),
        VisitStatus.withScribe => ('With scribe', Clinic.statusWaiting),
        VisitStatus.readyForReview => ('Ready for review', Clinic.statusActive),
        VisitStatus.changesRequested =>
          ('Changes requested', Clinic.statusWaiting),
        VisitStatus.approved => ('Approved', Clinic.statusDone),
        VisitStatus.syncedToEhr => ('In EHR', Clinic.statusDone),
        VisitStatus.failed => ('Needs attention', Clinic.statusAlert),
      };

  String _dur(int ms) {
    final s = ms ~/ 1000;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Widget _emptyState(IconData icon, String title, String body) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 48, color: Clinic.secondary.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      color: Clinic.brandNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 4),
              Text(body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Clinic.secondary.withValues(alpha: 0.6),
                      fontSize: 12)),
            ],
          ),
        ),
      );

  // --- Connectivity / sync banner (unchanged behaviour) ---

  Widget _connectivityBar(ClinicalService svc) {
    return ValueListenableBuilder<bool>(
      valueListenable: svc.online,
      builder: (context, online, _) {
        return ValueListenableBuilder<int>(
          valueListenable: svc.pendingSync,
          builder: (context, pending, child) {
            if (online && pending == 0) return const SizedBox.shrink();
            final offline = !online;
            final color = offline ? Clinic.priorityMedium : Clinic.primary;
            final text = offline
                ? (pending > 0
                    ? 'Offline · $pending change${pending == 1 ? '' : 's'} queued'
                    : 'Offline · changes will sync when reconnected')
                : 'Syncing $pending change${pending == 1 ? '' : 's'}…';
            return Container(
              width: double.infinity,
              color: color.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(offline ? Icons.cloud_off : Icons.cloud_sync,
                      size: 16, color: color),
                  const SizedBox(width: 8),
                  Text(text,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(svc.backendLabel,
                      style: TextStyle(
                          color: color.withValues(alpha: 0.8), fontSize: 11)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
