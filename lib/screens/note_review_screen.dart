import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/clinical_models.dart';
import '../services/clinical_service.dart';
import '../theme.dart';

/// The clinician's review of a scribe-completed note:
///   read -> small edits yourself  OR  request changes (comment to scribe)
///   OR  approve as final.
/// No "generate transcript" action; no EHR upload (the scribe does that).
class NoteReviewScreen extends StatefulWidget {
  final String visitId;
  const NoteReviewScreen({super.key, required this.visitId});

  @override
  State<NoteReviewScreen> createState() => _NoteReviewScreenState();
}

class _NoteReviewScreenState extends State<NoteReviewScreen> {
  bool _editing = false;
  // The sentence/phrase the doctor has highlighted in the note, so a change
  // request can be anchored to exactly that text for the scribe.
  String _selected = '';
  late TextEditingController _editCtrl;

  // The note body is fetched on open (the list only carries status). While the
  // fetch is in flight we show a loader; if it can't be loaded we offer a retry.
  bool _loadingNote = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController();
  }

  Future<void> _loadNote() async {
    if (!mounted) return;
    setState(() {
      _loadingNote = true;
      _loadFailed = false;
    });
    final ok = await context.read<ClinicalService>().ensureNote(widget.visitId);
    if (!mounted) return;
    setState(() {
      _loadingNote = false;
      // A hard failure: the fetch finished but no note body arrived (offline,
      // server error, …). Show a retry instead of re-fetching forever. A
      // still-with-scribe note never reaches this path — it shows the busy
      // state — so we don't need to special-case status here.
      final v = context.read<ClinicalService>().visitById(widget.visitId);
      _loadFailed = !ok && v?.note == null;
    });
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<ClinicalService>();
    final visit = svc.visitById(widget.visitId);

    return Scaffold(
      backgroundColor: Clinic.backgroundLight,
      appBar: AppBar(
        title: Text(visit?.patientName ?? 'Note review',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Clinic.brandNavy)),
      ),
      body: visit == null
          ? const Center(child: Text('Visit not found.'))
          : _body(context, svc, visit),
    );
  }

  Widget _body(BuildContext context, ClinicalService svc, Visit visit) {
    final note = visit.note;
    final isBusy = visit.status == VisitStatus.withScribe ||
        visit.status == VisitStatus.changesRequested ||
        visit.status == VisitStatus.pendingUpload;

    // The note is ready on the server but its body hasn't loaded onto the
    // device yet (still fetching, or the fetch failed). Show a loader / retry
    // rather than the "with scribe" copy, which would be misleading. Kick off
    // the fetch from here so it also recovers if the note is ever dropped (e.g.
    // a scribe revision invalidated the cached body). The _loadingNote guard
    // stops this from re-firing every rebuild.
    if (note == null && !isBusy) {
      if (_loadFailed) return _loadFailedState();
      if (!_loadingNote) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadNote());
      }
      return _loadingNoteState();
    }
    if (isBusy || note == null) {
      return _busyState(visit);
    }

    final reviewable = visit.status == VisitStatus.readyForReview;
    final approved = visit.status == VisitStatus.approved ||
        visit.status == VisitStatus.syncedToEhr;

    return Column(
      children: [
        _statusBanner(visit),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (note.feedback.isNotEmpty) _feedbackHistory(note),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Clinic.cardWhite,
                  borderRadius: BorderRadius.circular(Clinic.rCard),
                  border: Border.all(
                      color: _editing
                          ? Clinic.primary
                          : Clinic.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_editing ? Icons.edit : Icons.description,
                            color: Clinic.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                            _editing
                                ? 'Editing note'
                                : 'Clinical note · v${note.version}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Clinic.brandNavy)),
                        const Spacer(),
                        if (reviewable && !_editing)
                          TextButton.icon(
                            onPressed: () => _startEditing(note),
                            icon: const Icon(Icons.edit_note, size: 18),
                            label: const Text('Edit'),
                            style: TextButton.styleFrom(
                                foregroundColor: Clinic.primary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_editing)
                      TextField(
                        controller: _editCtrl,
                        autofocus: true,
                        maxLines: null,
                        minLines: 12,
                        style: const TextStyle(
                            color: Clinic.secondary, height: 1.5, fontSize: 14),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      )
                    else
                      SelectableText(note.content,
                          onSelectionChanged: (sel, _) => setState(() =>
                              _selected = sel.textInside(note.content).trim()),
                          style: const TextStyle(
                              color: Clinic.secondary,
                              height: 1.5,
                              fontSize: 14)),
                    if (!_editing && reviewable)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                            _selected.isEmpty
                                ? 'Tip: highlight a sentence to comment on it specifically.'
                                : 'Selected — tap "Comment on selection" below.',
                            style: TextStyle(
                                color: Clinic.secondary.withValues(alpha: 0.6),
                                fontSize: 12,
                                fontStyle: FontStyle.italic)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 90),
            ],
          ),
        ),
        if (_editing)
          _editActions(context, svc, visit)
        else if (reviewable)
          _reviewActions(context, svc, visit)
        else if (approved)
          _approvedFooter(),
      ],
    );
  }

  void _startEditing(ClinicalNote note) {
    _editCtrl.text = note.content;
    setState(() => _editing = true);
  }

  Widget _loadingNoteState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Clinic.primary),
            SizedBox(height: 18),
            Text('Loading the note…',
                style: TextStyle(color: Clinic.secondary)),
          ],
        ),
      ),
    );
  }

  Widget _loadFailedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off,
                size: 44, color: Clinic.secondary.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            const Text("Couldn't load the note.",
                style: TextStyle(
                    color: Clinic.brandNavy, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Clinic.secondary.withValues(alpha: 0.7),
                    fontSize: 12)),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Clinic.primary),
              onPressed: _loadingNote ? null : _loadNote,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _busyState(Visit visit) {
    final msg = switch (visit.status) {
      VisitStatus.pendingUpload => 'Waiting to upload the recording…',
      VisitStatus.withScribe => 'With the scribe — completing the note…',
      VisitStatus.changesRequested =>
        'Sent back to the scribe with your comments…',
      _ => 'Working…',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Clinic.primary),
            const SizedBox(height: 18),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Clinic.secondary)),
            const SizedBox(height: 6),
            const Text('This updates automatically.',
                style: TextStyle(color: Clinic.secondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _statusBanner(Visit visit) {
    final ts = DateFormat('MMM d, HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(visit.createdAt));
    return Container(
      width: double.infinity,
      color: Clinic.surfaceLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _statusChip(visit.status),
          const Spacer(),
          Text(ts,
              style: TextStyle(
                  color: Clinic.secondary.withValues(alpha: 0.7), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _feedbackHistory(ClinicalNote note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Clinic.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Clinic.rControl),
        border: Border.all(color: Clinic.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Comments to scribe',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Clinic.brandNavy)),
          const SizedBox(height: 8),
          ...note.feedback.map((f) {
            final t = DateFormat('MMM d, HH:mm')
                .format(DateTime.fromMillisecondsSinceEpoch(f.at));
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• ${f.message}  ($t)',
                  style: const TextStyle(color: Clinic.secondary, fontSize: 13)),
            );
          }),
        ],
      ),
    );
  }

  Widget _editActions(BuildContext context, ClinicalService svc, Visit visit) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Clinic.cardWhite,
          border: Border(top: BorderSide(color: Clinic.borderColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Clinic.secondary,
                  side: const BorderSide(color: Clinic.borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => setState(() => _editing = false),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Clinic.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  final text = _editCtrl.text.trim();
                  if (text.isEmpty) return;
                  await svc.saveNoteEdit(visit.id, text);
                  if (!context.mounted) return;
                  setState(() => _editing = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Your edits were saved.')));
                },
                icon: const Icon(Icons.save),
                label: const Text('Save edits'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewActions(BuildContext context, ClinicalService svc, Visit visit) {
    final hasSel = _selected.isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Clinic.cardWhite,
          border: Border(top: BorderSide(color: Clinic.borderColor)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasSel) ...[
              _selectionChip(),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Clinic.primary,
                      side: const BorderSide(color: Clinic.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _promptChanges(context, svc, visit,
                        quote: hasSel ? _selected : ''),
                    icon: Icon(hasSel ? Icons.comment : Icons.forum_outlined,
                        size: 18),
                    label: Text(
                        hasSel ? 'Comment on selection' : 'Request full review',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Clinic.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _confirmApprove(context, svc, visit),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectionChip() {
    final short =
        _selected.length > 90 ? '${_selected.substring(0, 90)}…' : _selected;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Clinic.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Clinic.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.format_quote, size: 14, color: Clinic.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text('"$short"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12,
                    color: Clinic.brandNavy,
                    fontStyle: FontStyle.italic)),
          ),
          InkWell(
            onTap: () => setState(() => _selected = ''),
            child: Icon(Icons.close,
                size: 16, color: Clinic.secondary.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _approvedFooter() {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Clinic.cardWhite,
          border: Border(top: BorderSide(color: Clinic.borderColor)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified, color: Clinic.statusDone),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Approved as final. The scribe will upload it to the EHR.',
                style: TextStyle(color: Clinic.secondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptChanges(
      BuildContext context, ClinicalService svc, Visit visit,
      {String quote = ''}) async {
    final controller = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Clinic.cardWhite,
        title: Text(quote.isEmpty
            ? 'Request a full review'
            : 'Comment on selection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (quote.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Clinic.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                      left: BorderSide(color: Clinic.primary, width: 3)),
                ),
                child: Text('"$quote"',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Clinic.brandNavy,
                        fontStyle: FontStyle.italic)),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: quote.isEmpty
                    ? 'What should the scribe change? e.g. "Add the BP reading to Objective."'
                    : 'What should change about this sentence?',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Clinic.primary),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Send to scribe'),
          ),
        ],
      ),
    );
    if (comment != null && comment.isNotEmpty) {
      // Anchor the comment to the highlighted sentence so the scribe knows
      // exactly what to change.
      final message = quote.isEmpty ? comment : 'Re: "$quote"\n$comment';
      await svc.requestChanges(visit.id, message);
      if (mounted) setState(() => _selected = '');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sent to the scribe with your comments.')));
      }
    }
  }

  Future<void> _confirmApprove(
      BuildContext context, ClinicalService svc, Visit visit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Clinic.cardWhite,
        title: const Text('Approve as final?'),
        content: const Text(
            'This marks the note as the final version and hands it to the '
            'scribe for EHR upload. You won\'t be able to edit it afterwards.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not yet')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Clinic.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await svc.approve(visit.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note approved as final.')));
      }
    }
  }

  Widget _statusChip(VisitStatus status) {
    final color = switch (status) {
      VisitStatus.readyForReview => Clinic.statusActive,
      VisitStatus.approved || VisitStatus.syncedToEhr => Clinic.statusDone,
      VisitStatus.failed => Clinic.statusAlert,
      _ => Clinic.statusWaiting,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Clinic.rChip),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Text(status.label.toUpperCase(),
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.5)),
    );
  }
}
