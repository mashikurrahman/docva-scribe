import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../logo.dart';
import '../api/clinical_models.dart';
import '../services/clinical_service.dart';
import '../widgets/anot_header.dart';
import '../widgets/pressable.dart';
import 'add_patient_screen.dart';
import 'patient_visit_screen.dart';
import 'note_review_screen.dart';
import 'profile_screen.dart';

enum _PatientSort { time, name }

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  /// The clinic day currently being viewed (web-style day-by-day schedule).
  /// Defaults to today; the doctor can tap any previous/future day.
  DateTime _selectedDay = DateTime.now();
  _PatientSort _sort = _PatientSort.time;

  /// Day-strip scroller — centred on "Today" when the screen first opens.
  final ScrollController _weekScroll = ScrollController();
  // Day chip = 54 width + 4+4 margin; the strip starts 3 days before today.
  static const double _chipExtent = 62;
  static const int _todayIndex = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerToday());
  }

  @override
  void dispose() {
    _weekScroll.dispose();
    super.dispose();
  }

  void _centerToday() {
    if (!_weekScroll.hasClients) return;
    final vp = _weekScroll.position.viewportDimension;
    // Centre of Today's chip minus half the viewport = scroll so it sits middle.
    final target = (12 + _todayIndex * _chipExtent + 27) - vp / 2;
    _weekScroll.jumpTo(target.clamp(0.0, _weekScroll.position.maxScrollExtent));
  }

  /// Bulk-reschedule selection. When [_selectMode] is on, un-recorded patient
  /// rows show a checkbox and can be moved to another date together.
  bool _selectMode = false;
  final Set<int> _selected = {};
  bool _moving = false;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _onSelectedDay(int millis) =>
      _sameDay(DateTime.fromMillisecondsSinceEpoch(millis), _selectedDay);

  /// The scheduled encounter time for a patient (epoch millis): the chosen
  /// visit date, else an appointment, else the latest visit, else last contact.
  int _encounterMillis(Patient p, ClinicalService svc) {
    if (p.visitDate != 0) return p.visitDate;
    final v = svc.latestVisitForPatient(p.id);
    if (v != null && v.visitDate != 0) return v.visitDate;
    if (v != null) return v.createdAt;
    return p.lastContactDate;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final svc = context.watch<ClinicalService>();
    var patients = state.visiblePatients;

    // Filter to the selected day. Searching bypasses the day filter so any
    // patient is always findable.
    final searching = state.searchQuery.trim().isNotEmpty;
    if (!searching) {
      patients = patients
          .where((p) => _onSelectedDay(_encounterMillis(p, svc)))
          .toList();
    }

    // Sort by time (ascending, like the web schedule) or by name.
    final sorted = [...patients];
    if (_sort == _PatientSort.name) {
      sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      sorted.sort((a, b) =>
          _encounterMillis(a, svc).compareTo(_encounterMillis(b, svc)));
    }

    // The first un-recorded patient is highlighted in NEXT UP and excluded from
    // the list so no one appears twice.
    Patient? nextUp;
    for (final p in sorted) {
      if (!svc.patientRecorded(p.id)) {
        nextUp = p;
        break;
      }
    }
    final toRecordCount =
        sorted.where((p) => !svc.patientRecorded(p.id)).length;

    // Only un-recorded patients can be moved (recorded ones are already done,
    // and deleting their visit would discard the audio).
    final selectableIds =
        sorted.where((p) => !svc.patientRecorded(p.id)).map((p) => p.id).toSet();

    return Scaffold(
      backgroundColor: Clinic.backgroundLight,
      body: Column(
        children: [
          _header(context, state, svc, sorted.length - toRecordCount,
              sorted.length),
          _syncStatusBar(svc),
          _loadErrorBanner(svc),
          _recoveredRecordingBanner(context, state),
          _weekStrip(),
          _searchField(state),
          _listHeader(selectableIds),
          if (!_selectMode)
            Pressable(
                child: _nextPatientSuggestionCard(
                    context, svc, nextUp, toRecordCount)),
          if (svc.loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await svc.refresh();
                await state.refreshPatients();
              },
              // In select mode the NEXT UP patient is also selectable, so don't
              // exclude them from the list.
              child: _encounterList(
                  context, svc, sorted, _selectMode ? null : nextUp?.id),
            ),
          ),
          if (_selectMode) _moveBar(context, svc, state),
        ],
      ),
    );
  }

  // --- Stylish gradient header (greeting + actions) ---

  Widget _header(BuildContext context, AppState state, ClinicalService svc,
      int recorded, int total) {
    final initial = (state.currentUser?.fullName.isNotEmpty ?? false)
        ? state.currentUser!.fullName.replaceFirst('Dr. ', '')[0].toUpperCase()
        : '?';
    return AnotHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 14, left: 2),
            child: AnotLogo(height: 22, white: true),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_greeting()},',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(_doctorName(state),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: -0.3)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.event_outlined,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.8)),
                    const SizedBox(width: 5),
                    Text(DateFormat('EEEE, MMMM d').format(DateTime.now()),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12)),
                    const SizedBox(width: 10),
                    Flexible(child: _headerProgress(recorded, total)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          HeaderIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh',
            onTap: svc.loading
                ? null
                : () async {
                    await svc.refresh();
                    await state.refreshPatients();
                  },
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.6)),
              ),
              child: CircleAvatar(
                radius: 19,
                backgroundColor: Colors.white,
                child: Text(initial,
                    style: const TextStyle(
                        color: Clinic.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }

  /// Compact day progress shown in the header (replaces the bulky in-list card,
  /// freeing vertical space for the patient list itself).
  Widget _headerProgress(int recorded, int total) {
    if (total == 0) return const SizedBox.shrink();
    final pct = (recorded / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.task_alt, size: 11, color: Colors.white),
          const SizedBox(width: 5),
          Text('$recorded/$total',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          SizedBox(
            width: 34,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Week day-strip (schedule) ---

  Widget _weekStrip() {
    final start = DateTime.now().subtract(const Duration(days: 3));
    final base = DateTime(start.year, start.month, start.day);
    final days = List.generate(21, (i) => base.add(Duration(days: i)));
    return Container(
      // Float up slightly so the chips overlap the header's curved edge.
      transform: Matrix4.translationValues(0, -16, 0),
      padding: const EdgeInsets.only(top: 4, bottom: 0),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _weekScroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                ...days.map((d) => Pressable(child: _dayChip(d))),
              ]),
            ),
          ),
          IconButton(
            tooltip: 'Pick a date',
            onPressed: _pickDay,
            icon: const Icon(Icons.calendar_month, color: Clinic.primary),
          ),
        ],
      ),
    );
  }

  Widget _dayChip(DateTime day) {
    final isToday = _sameDay(day, DateTime.now());
    final selected = _sameDay(day, _selectedDay);
    return GestureDetector(
      onTap: () => setState(() {
        _selectedDay = day;
      }),
      child: Container(
        width: 54,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          // Selected = deep DOCVA navy with a 3px electric-blue base rule
          // (the logo's exact duo) — unmistakably not a soft blue Anot pill.
          color: selected ? Clinic.brandNavy : Clinic.cardWhite,
          borderRadius: BorderRadius.circular(Clinic.rControl),
          border: selected
              ? const Border(
                  top: BorderSide(color: Clinic.brandNavy),
                  left: BorderSide(color: Clinic.brandNavy),
                  right: BorderSide(color: Clinic.brandNavy),
                  bottom: BorderSide(color: Clinic.primary, width: 3),
                )
              : Border.all(color: Clinic.borderColor),
          boxShadow: Clinic.rowShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(DateFormat('EEE').format(day).toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.75)
                        : Clinic.secondary.withValues(alpha: 0.7))),
            const SizedBox(height: 2),
            Text('${day.day}',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : Clinic.brandNavy)),
            const SizedBox(height: 2),
            Text(isToday ? 'TODAY' : '·',
                style: TextStyle(
                    fontSize: isToday ? 7 : 7,
                    fontWeight: FontWeight.bold,
                    color: isToday
                        ? (selected ? Colors.white : Clinic.primary)
                        : Colors.transparent)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Go to date',
    );
    if (picked != null) setState(() => _selectedDay = picked);
  }

  // --- Search + list header ---

  Widget _searchField(AppState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: SizedBox(
        height: 44,
        child: TextField(
          onChanged: (v) => state.searchQuery = v,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search patients, MRN…',
            prefixIcon: const Icon(Icons.search, color: Clinic.primary),
            filled: true,
            fillColor: Clinic.cardWhite,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Clinic.rControl),
                borderSide: const BorderSide(color: Clinic.borderColor)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Clinic.rControl),
                borderSide: const BorderSide(color: Clinic.borderColor)),
          ),
        ),
      ),
    );
  }

  Widget _listHeader(Set<int> selectableIds) {
    // Select mode: show selection count + select-all / cancel.
    if (_selectMode) {
      final allSelected =
          selectableIds.isNotEmpty && _selected.containsAll(selectableIds);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 2),
        child: Row(
          children: [
            Text('${_selected.length} SELECTED',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Clinic.primary)),
            const Spacer(),
            TextButton(
              onPressed: selectableIds.isEmpty
                  ? null
                  : () => setState(() {
                        if (allSelected) {
                          _selected.clear();
                        } else {
                          _selected
                            ..clear()
                            ..addAll(selectableIds);
                        }
                      }),
              style: TextButton.styleFrom(
                  foregroundColor: Clinic.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(allSelected ? 'Clear all' : 'Select all',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: () => setState(() {
                _selectMode = false;
                _selected.clear();
              }),
              style: TextButton.styleFrom(
                  foregroundColor: Clinic.secondary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 2),
      child: Row(
        children: [
          Text('PATIENT LIST',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Clinic.secondary.withValues(alpha: 0.7))),
          const Spacer(),
          // Move/reschedule: enter multi-select (only when there's something
          // movable on this view).
          if (selectableIds.isNotEmpty) ...[
            _headerAction(
              icon: Icons.event_repeat,
              label: 'Move',
              onTap: () => setState(() => _selectMode = true),
            ),
            const SizedBox(width: 6),
          ],
          // Add patient (kept in-header, never floating over the list).
          _headerAction(
            icon: Icons.person_add,
            label: 'Add',
            filled: true,
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddPatientScreen())),
          ),
          const SizedBox(width: 6),
          // Sort dropdown (Time / Name) — mirrors the web "Time" selector.
          Container(
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
                  child: DropdownButton<_PatientSort>(
                    value: _sort,
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down,
                        size: 18, color: Clinic.secondary),
                    style: const TextStyle(
                        fontSize: 12,
                        color: Clinic.brandNavy,
                        fontWeight: FontWeight.w600),
                    items: const [
                      DropdownMenuItem(
                          value: _PatientSort.time, child: Text('Time')),
                      DropdownMenuItem(
                          value: _PatientSort.name, child: Text('Name')),
                    ],
                    onChanged: (v) => setState(() => _sort = v ?? _sort),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Bulk reschedule ("Move to date") ---

  Widget _moveBar(BuildContext context, ClinicalService svc, AppState state) {
    final n = _selected.length;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Clinic.cardWhite,
          border: const Border(top: BorderSide(color: Clinic.borderColor)),
          boxShadow: Clinic.cardShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                  n == 0
                      ? 'Select patients to move'
                      : n == 1
                          ? '1 patient · pick date & time'
                          : '$n patients · pick date',
                  style: TextStyle(
                      color: n == 0
                          ? Clinic.secondary.withValues(alpha: 0.7)
                          : Clinic.brandNavy,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Clinic.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: (n == 0 || _moving)
                  ? null
                  : () => _moveSelected(context, svc, state),
              icon: _moving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.event_available, size: 18),
              label: Text(_moving ? 'Moving…' : 'Move to date',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _moveSelected(
      BuildContext context, ClinicalService svc, AppState state) async {
    final ids = _selected.toList();
    final single = ids.length == 1;
    final now = DateTime.now();
    final base = _selectedDay;
    var initial = DateTime(base.year, base.month, base.day)
        .add(const Duration(days: 1));
    if (initial.isBefore(now)) initial = now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: single ? 'Move to date' : 'Move ${ids.length} patients to',
    );
    if (picked == null) return;

    // A single patient also gets a specific time; bulk moves keep each visit's
    // original time (per the workflow — no per-patient time for a batch).
    String? overrideTime;
    if (single) {
      final v = svc.latestVisitForPatient(ids.first);
      final initialTime = (v != null && v.visitDate != 0)
          ? TimeOfDay.fromDateTime(
              DateTime.fromMillisecondsSinceEpoch(v.visitDate))
          : TimeOfDay.now();
      if (!context.mounted) return;
      final t = await showTimePicker(
        context: context,
        initialTime: initialTime,
        helpText: 'Visit time',
      );
      if (t == null) return; // cancelled the time step → abort the move
      overrideTime =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }

    setState(() => _moving = true);
    var moved = 0;
    for (final pid in ids) {
      final v = svc.latestVisitForPatient(pid);
      if (v == null) continue;
      if (await svc.rescheduleVisit(v.id, picked, overrideTime: overrideTime)) {
        moved++;
      }
    }
    await svc.refresh();
    await state.refreshPatients();
    if (!context.mounted) return;
    setState(() {
      _moving = false;
      _selectMode = false;
      _selected.clear();
    });
    final whenLabel = overrideTime != null
        ? '${DateFormat('EEE, MMM d').format(picked)}, $overrideTime'
        : DateFormat('EEE, MMM d').format(picked);
    final msg = moved == 0
        ? (svc.error ?? 'Could not move the patients.')
        : 'Moved $moved patient${moved == 1 ? '' : 's'} to $whenLabel.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- The schedule list, split into "To see" and "Recorded" ---

  int _recordedMillis(Patient p, ClinicalService svc) =>
      svc.recordedVisitForPatient(p.id)?.createdAt ?? 0;

  Widget _encounterList(BuildContext context, ClinicalService svc,
      List<Patient> sorted, int? excludeId) {
    final items =
        sorted.where((p) => p.id != excludeId).toList(growable: false);
    if (items.isEmpty) {
      return ListView(children: [const SizedBox(height: 80), _emptyState()]);
    }

    // Split the day into who's still to be seen vs. who's been recorded.
    final toSee = items.where((p) => !svc.patientRecorded(p.id)).toList();
    final done = items.where((p) => svc.patientRecorded(p.id)).toList()
      // Most-recently recorded first, so the just-finished visit sits on top.
      ..sort((a, b) =>
          _recordedMillis(b, svc).compareTo(_recordedMillis(a, svc)));

    // Day progress now lives compactly in the header (frees list space).
    final children = <Widget>[];

    if (toSee.isNotEmpty) {
      children.add(_listSectionHeader(
          Icons.schedule, 'To see', toSee.length, Clinic.primary));
      for (final p in toSee) {
        final selected = _selected.contains(p.id);
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Pressable(
            child: _encounterRow(context, p, svc,
                selecting: _selectMode,
                selected: selected,
                onToggle: () => setState(() {
                      if (selected) {
                        _selected.remove(p.id);
                      } else {
                        _selected.add(p.id);
                      }
                    })),
          ),
        ));
      }
    }

    if (done.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(_listSectionHeader(
          Icons.check_circle, 'Recorded', done.length, Clinic.statusActive));
      for (final p in done) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Pressable(child: _encounterRow(context, p, svc, done: true)),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: children,
    );
  }

  /// Compact header action chip. `filled` = electric-blue primary (Add);
  /// otherwise an outlined navy secondary (Move).
  Widget _headerAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    final fg = filled ? Colors.white : Clinic.brandNavy;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? Clinic.primary : Clinic.cardWhite,
          borderRadius: BorderRadius.circular(Clinic.rChip),
          border: Border.all(
              color: filled ? Clinic.primary : Clinic.outlineColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _listSectionHeader(
      IconData icon, String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 9, left: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label.toUpperCase(),
              style: TextStyle(
                  color: Clinic.secondary.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6)),
          const SizedBox(width: 6),
          Text('($count)',
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // --- A single web-style encounter row ---

  Widget _encounterRow(BuildContext context, Patient p, ClinicalService svc,
      {bool done = false,
      bool selecting = false,
      bool selected = false,
      VoidCallback? onToggle}) {
    final recorded = svc.patientRecorded(p.id);
    final recCount = recorded ? svc.recordedCountForPatient(p.id) : 0;
    final status = recorded ? svc.recordedVisitForPatient(p.id)?.status : null;
    final (badgeLabel, badgeColor) = _statusBadge(p, svc, recorded);
    final dt = DateTime.fromMillisecondsSinceEpoch(_encounterMillis(p, svc));
    final visitType = _visitTypeOf(p, svc);
    final subtitle =
        'MRN ${p.mrn}${visitType.isNotEmpty ? '  ·  $visitType' : ''}';
    final cardBg = _cardBackground(recorded, status, selected);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(Clinic.rCard),
        border: Border.all(
            color: selected
                ? Clinic.primary
                : recorded
                    ? badgeColor.withValues(alpha: 0.30)
                    : Clinic.borderColor,
            width: selected ? 1.5 : 1),
        boxShadow: Clinic.rowShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: selecting
              ? onToggle
              : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PatientVisitScreen(patientId: p.id))),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Coloured status accent bar.
                Container(width: 5, color: badgeColor),
                if (selecting)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: selected
                            ? Clinic.primary
                            : Clinic.secondary.withValues(alpha: 0.4),
                        size: 22),
                  ),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Row(
                      children: [
                        // Time column.
                        SizedBox(
                          width: 44,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(DateFormat('h:mm').format(dt),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Clinic.brandNavy)),
                              Text(DateFormat('a').format(dt),
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Clinic.secondary
                                          .withValues(alpha: 0.6))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        _rowAvatar(p, done),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Clinic.brandNavy,
                                      fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color:
                                          Clinic.secondary.withValues(alpha: 0.7),
                                      fontSize: 11)),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _statusPill(badgeLabel, badgeColor),
                                  if (recCount > 1) _recordingsBadge(recCount),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!selecting) _recordButton(context, p, svc, recorded),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Row avatar with a small green check badge once the patient is recorded.
  Widget _rowAvatar(Patient p, bool done) {
    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: done
          ? Clinic.statusActive.withValues(alpha: 0.14)
          : Clinic.surfaceLight,
      child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
          style: TextStyle(
              color: done ? Clinic.statusActive : Clinic.brandNavy,
              fontWeight: FontWeight.bold,
              fontSize: 13)),
    );
    if (!done) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -3,
          bottom: -3,
          child: Container(
            decoration: const BoxDecoration(
                color: Clinic.cardWhite, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle,
                size: 15, color: Clinic.statusActive),
          ),
        ),
      ],
    );
  }

  /// "N recordings" badge — shown when a patient has more than one recording,
  /// mirroring the web scribe panel where each recording is its own card.
  Widget _recordingsBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Clinic.brandNavy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Clinic.rChip),
        border: Border.all(color: Clinic.brandNavy.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.graphic_eq, size: 10, color: Clinic.brandNavy),
          const SizedBox(width: 3),
          Text('$count recordings',
              style: const TextStyle(
                  color: Clinic.brandNavy,
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// Sharp, bordered status tag with a leading status dot — a DOCVA signature
  /// that replaces the soft rounded clinical pill.
  Widget _statusPill(String label, Color color) {
    return Container(
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
  }

  /// State-tinted card background so the day reads at a glance:
  ///   upcoming (not recorded) -> clean white
  ///   with scribe / uploading -> soft slate  (in the queue, waiting)
  ///   note ready to review    -> soft green   (your turn)
  ///   changes requested       -> soft amber
  ///   approved / in EHR       -> faint green  (done)
  ///   failed                  -> soft red     (needs attention)
  Color _cardBackground(bool recorded, VisitStatus? status, bool selected) {
    if (selected) return Clinic.primary.withValues(alpha: 0.10);
    if (!recorded) return Clinic.cardWhite;
    return switch (status) {
      VisitStatus.readyForReview =>
        Clinic.statusActive.withValues(alpha: 0.07), // your turn — soft blue
      VisitStatus.changesRequested =>
        Clinic.statusWaiting.withValues(alpha: 0.10),
      VisitStatus.approved ||
      VisitStatus.syncedToEhr =>
        Clinic.statusDone.withValues(alpha: 0.05), // filed — faint navy
      VisitStatus.failed => Clinic.statusAlert.withValues(alpha: 0.08),
      _ => Clinic.surfaceLight, // with scribe / pending upload -> waiting
    };
  }

  /// Primary action on a patient row. Mirrors where the visit is in the
  /// workflow so the doctor always knows the next step:
  ///   not recorded            -> Record
  ///   scribe finished a note  -> Review   (open the note to edit/approve)
  ///   approved / in EHR       -> View
  ///   otherwise recorded      -> Add      (capture another recording)
  Widget _recordButton(
      BuildContext context, Patient p, ClinicalService svc, bool recorded) {
    final visit = recorded ? svc.recordedVisitForPatient(p.id) : null;
    switch (visit?.status) {
      case VisitStatus.readyForReview:
        return _pillButton(
          label: 'Review',
          icon: Icons.rate_review,
          color: Clinic.statusActive,
          onTap: () => _openReview(context, visit!.id),
        );
      case VisitStatus.approved:
      case VisitStatus.syncedToEhr:
        return _pillButton(
          label: 'View',
          icon: Icons.visibility_outlined,
          color: Clinic.statusDone,
          onTap: () => _openReview(context, visit!.id),
        );
      default:
        return _pillButton(
          label: recorded ? 'Add' : 'Record',
          icon: Icons.mic,
          color: Clinic.primary,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  PatientVisitScreen(patientId: p.id, autoStart: true))),
        );
    }
  }

  void _openReview(BuildContext context, String visitId) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => NoteReviewScreen(visitId: visitId)));

  Widget _pillButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 14),
      label: Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  /// (label, colour) for the status pill + accent bar. Un-recorded = Upcoming
  /// (blue); otherwise derived from the visit's note workflow status.
  (String, Color) _statusBadge(Patient p, ClinicalService svc, bool recorded) {
    if (!recorded) return ('Upcoming', Clinic.statusActive);
    final v = svc.recordedVisitForPatient(p.id);
    switch (v?.status) {
      case VisitStatus.withScribe:
        return ('With Scribe', Clinic.statusWaiting);
      case VisitStatus.readyForReview:
        return ('Note ready to review', Clinic.statusActive);
      case VisitStatus.changesRequested:
        return ('Changes requested', Clinic.statusWaiting);
      case VisitStatus.approved:
        return ('Approved', Clinic.statusDone);
      case VisitStatus.syncedToEhr:
        return ('In EHR', Clinic.statusDone);
      case VisitStatus.pendingUpload:
        return ('Pending upload', Clinic.statusWaiting);
      case VisitStatus.failed:
        return ('Needs attention', Clinic.statusAlert);
      default:
        final label = svc.patientStatusLabel(p.id);
        return (label.isEmpty ? 'Recorded' : label, Clinic.statusActive);
    }
  }

  // --- Greeting / header helpers ---

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _doctorName(AppState state) =>
      (state.currentUser?.fullName.isNotEmpty ?? false)
          ? state.currentUser!.fullName
          : 'Doctor';

  /// Visit type: chosen on add, else the latest visit's type. '' when unknown.
  String _visitTypeOf(Patient p, ClinicalService svc) => p.visitType.isNotEmpty
      ? p.visitType
      : (svc.latestVisitForPatient(p.id)?.visitType ?? '');

  /// 'YYYY-MM-DD' DOB for display (the server may send an ISO timestamp).
  String _dobOf(Patient p) {
    final d = p.dob.trim();
    if (d.isEmpty || d == 'null') return '';
    return d.length >= 10 ? d.substring(0, 10) : d;
  }

  Widget _emptyState() {
    final isToday = _sameDay(_selectedDay, DateTime.now());
    final dayLabel = isToday
        ? 'today'
        : 'on ${DateFormat('EEEE, MMM d').format(_selectedDay)}';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_outlined,
                size: 48, color: Clinic.secondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('No patients scheduled $dayLabel.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Clinic.secondary.withValues(alpha: 0.8))),
            const SizedBox(height: 4),
            Text('Tap "Add" to schedule one.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Clinic.secondary.withValues(alpha: 0.5),
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }

  /// Shows a banner when the last server load failed (so the clinician knows
  /// the list may be stale rather than silently showing nothing).
  Widget _loadErrorBanner(ClinicalService svc) {
    if (svc.error == null || svc.loading) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Clinic.priorityHigh.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 16, color: Clinic.priorityHigh),
          const SizedBox(width: 10),
          Expanded(
            child: Text(svc.error!,
                style: const TextStyle(
                    color: Clinic.priorityHigh,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _syncStatusBar(ClinicalService svc) {
    return ValueListenableBuilder<int>(
      valueListenable: svc.pendingSync,
      builder: (context, pending, child) {
        if (pending == 0) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: Clinic.primary.withValues(alpha: 0.1),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: Row(
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Clinic.primary),
                ),
              ),
              const SizedBox(width: 10),
              Text('Syncing $pending offline visit records...',
                  style: const TextStyle(
                      color: Clinic.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  Widget _recoveredRecordingBanner(BuildContext context, AppState state) {
    final rec = state.recoveredRecording;
    if (rec == null) return const SizedBox.shrink();
    final patientName = state.patientNameById(rec.patientId);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Clinic.priorityMedium.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Clinic.priorityMedium.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Clinic.priorityMedium, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Interrupted recording for $patientName recovered.',
                style: const TextStyle(
                    color: Clinic.brandNavy,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              state.clearRecoveredRecording();
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PatientVisitScreen(
                      patientId: rec.patientId, autoStart: true)));
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              backgroundColor: Clinic.priorityMedium,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Resume',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Clinic.secondary),
            onPressed: () => state.clearRecoveredRecording(),
          ),
        ],
      ),
    );
  }

  /// "NEXT UP" highlight for the first un-recorded patient. Excluded from the
  /// list so it's shown exactly once. Tapping opens the patient; Start records.
  Widget _nextPatientSuggestionCard(BuildContext context, ClinicalService svc,
      Patient? next, int remaining) {
    if (next == null) return const SizedBox.shrink();
    final p = next;
    final visitType = _visitTypeOf(p, svc);
    final dob = _dobOf(p);
    final sub = [
      if (visitType.isNotEmpty) visitType,
      if (dob.isNotEmpty) 'DOB $dob',
    ].join('  ·  ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PatientVisitScreen(patientId: p.id))),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Clinic.primary.withValues(alpha: 0.14),
                  Clinic.primary.withValues(alpha: 0.04),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Clinic.primary.withValues(alpha: 0.35)),
              boxShadow: Clinic.rowShadow,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Clinic.primary,
                  child: Text(
                    p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text('NEXT UP',
                              style: TextStyle(
                                  color: Clinic.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 9,
                                  letterSpacing: 1.2)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Clinic.primary,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text('$remaining to record',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Clinic.brandNavy,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      if (sub.isNotEmpty)
                        Text(sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Clinic.secondary.withValues(alpha: 0.75),
                                fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => PatientVisitScreen(
                              patientId: p.id, autoStart: true))),
                  style: FilledButton.styleFrom(
                    backgroundColor: Clinic.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.mic, size: 14),
                  label: const Text('Start',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
