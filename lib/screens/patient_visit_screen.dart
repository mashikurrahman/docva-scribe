import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/clinical_service.dart';
import '../theme.dart';
import '../widgets/pressable.dart';

/// Per-patient capture screen: record / pause / stop / manage audio. Recording
/// is the hero — the rest (transcription, notes, EHR) happens in the web app.
class PatientVisitScreen extends StatefulWidget {
  final int patientId;
  final bool autoStart;
  const PatientVisitScreen({super.key, required this.patientId, this.autoStart = false});

  @override
  State<PatientVisitScreen> createState() => _PatientVisitScreenState();
}

class _PatientVisitScreenState extends State<PatientVisitScreen>
    with SingleTickerProviderStateMixin {
  // Drives the flowing motion of the live waveform (only runs while recording).
  late final AnimationController _waveCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = context.read<AppState>();
      await state.openPatientVisit(widget.patientId);
      // Pre-warm mic permission so the auto-start (and the first manual tap)
      // begins capture in a single tap, without the OS dialog racing it.
      final granted = await state.ensureMicPermission();
      if (widget.autoStart && granted && !state.isRecording) {
        await _start();
      }
    });
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  /// Starts recording — but first the clinician must confirm the patient has
  /// agreed to be recorded (the in-app consent gate, mirroring the web app).
  Future<void> _start() async {
    final state = context.read<AppState>();
    if (state.isRecording) return;
    final ok = await _confirmConsent();
    if (ok != true || !mounted) return;
    await state.startRecording(widget.patientId);
  }

  /// Patient-recording consent gate shown before the mic starts. The clinician
  /// confirms the patient was informed and agreed to be recorded; only then does
  /// capture begin. (The server-side consent record is sent silently at upload.)
  Future<bool?> _confirmConsent() {
    final patient = context.read<AppState>().selectedPatient;
    final who = patient?.name ?? 'this patient';
    bool checked = false;
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Clinic.cardWhite,
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Clinic.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Clinic.rCard),
                ),
                child: const Icon(Icons.mic, color: Clinic.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Patient recording consent',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Clinic.brandNavy)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Before recording this encounter, confirm that $who has been '
                'informed that audio will be captured for clinical documentation '
                'and has agreed to be recorded.',
                style: const TextStyle(
                    fontSize: 14, height: 1.5, color: Clinic.secondary),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => setLocal(() => checked = !checked),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: checked,
                        activeColor: Clinic.primary,
                        onChanged: (v) => setLocal(() => checked = v ?? false),
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('Patient authorizes recording',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Clinic.secondary)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed:
                  checked ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Start recording'),
            ),
          ],
        ),
      ),
    );
  }

  /// Stop recording. The recording is saved and shown immediately; securing it
  /// at rest and sending it to the scribe happen in the background (offline-safe)
  /// so a long recording never freezes the app on stop. No review screen — the
  /// scribe completes the note; it appears in the Notes tab when ready.
  /// A recording longer than this asks for confirmation before a whole-card tap
  /// ends it. The card is a deliberately huge target, so a stray tap during a
  /// long visit would otherwise split the encounter into two files. The explicit
  /// stop button is a deliberate press and never asks.
  static const _confirmStopAfter = Duration(minutes: 2);

  /// Stop triggered by tapping the card. Confirms first once the recording is
  /// long enough to be worth protecting; short ones stop immediately (cheap to
  /// redo, and the prompt would just be friction).
  Future<void> _stopFromCardTap(AppState state) async {
    if (state.recordingSeconds >= _confirmStopAfter.inSeconds) {
      final ok = await _confirmStop(state.recordingSeconds);
      if (ok != true || !mounted) return;
    }
    await _stopAndSubmit();
  }

  Future<bool?> _confirmStop(int seconds) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Clinic.cardWhite,
          title: const Text('Stop recording?',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Clinic.brandNavy)),
          content: Text(
            'This visit has been recording for ${_fmt(seconds * 1000)}. '
            'Stopping saves it and sends it to the scribe.',
            style: const TextStyle(
                fontSize: 14, height: 1.5, color: Clinic.secondary),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep recording')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Clinic.priorityHigh),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Stop'),
            ),
          ],
        ),
      );

  Future<void> _stopAndSubmit() async {
    final state = context.read<AppState>();
    final saved = await state.stopAndSaveRecording();
    if (!mounted) return;
    final msg = saved == null
        ? 'Nothing was recorded.'
        : 'Recording saved — securing it and sending to the scribe.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final svc = context.watch<ClinicalService>();
    final patient = state.selectedPatient;
    final isThis = state.recordingPatientId == widget.patientId;
    final recording = isThis && state.isRecording;

    // Run the waveform animation only while actively recording (saves power).
    if (recording && !state.isPaused && !_waveCtrl.isAnimating) {
      _waveCtrl.repeat();
    } else if ((!recording || state.isPaused) && _waveCtrl.isAnimating) {
      _waveCtrl.stop();
    }

    return Scaffold(
      backgroundColor: Clinic.backgroundLight,
      appBar: AppBar(
        title: Text(patient?.name ?? 'Visit',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Clinic.brandNavy)),
      ),
      body: Column(
        children: [
          if (patient != null) _patientInfoCard(patient, svc),
          _recorderCard(state, recording),
          const SizedBox(height: 12),
          Expanded(child: _recordingsList(state, svc)),
        ],
      ),
    );
  }

  /// Patient context shown above the recorder so the clinician sees who they're
  /// recording for: name, MRN, DOB/age, visit type and visit date.
  Widget _patientInfoCard(Patient patient, ClinicalService svc) {
    final visit = svc.latestVisitForPatient(patient.id);
    final visitType = patient.visitType.isNotEmpty
        ? patient.visitType
        : (visit?.visitType ?? '');
    final dobRaw = patient.dob.trim();
    final dob = (dobRaw.isEmpty || dobRaw == 'null')
        ? ''
        : (dobRaw.length >= 10 ? dobRaw.substring(0, 10) : dobRaw);
    final visitMillis = patient.visitDate != 0
        ? patient.visitDate
        : (visit?.visitDate ?? 0);
    final visitWhen = visitMillis != 0
        ? DateFormat('MMM d, yyyy · h:mm a')
            .format(DateTime.fromMillisecondsSinceEpoch(visitMillis))
        : '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Clinic.surfaceLight,
        borderRadius: BorderRadius.circular(Clinic.rCard),
        border: Border.all(color: Clinic.borderColor),
        boxShadow: Clinic.rowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Clinic.primary.withValues(alpha: 0.12),
                child: Text(
                    patient.name.isNotEmpty
                        ? patient.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Clinic.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Clinic.brandNavy,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    const SizedBox(height: 2),
                    Text('MRN ${patient.mrn}',
                        style: TextStyle(
                            color: Clinic.secondary.withValues(alpha: 0.7),
                            fontSize: 12)),
                  ],
                ),
              ),
              if (visitType.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Clinic.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Clinic.rChip),
                  ),
                  child: Text(visitType,
                      style: const TextStyle(
                          color: Clinic.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          if (dob.isNotEmpty || visitWhen.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (dob.isNotEmpty)
                  _infoItem(Icons.cake_outlined, 'DOB',
                      patient.age > 0 ? '$dob  (${patient.age} yr)' : dob),
                if (visitWhen.isNotEmpty)
                  _infoItem(Icons.event_outlined, 'Visit', visitWhen),
              ],
            ),
          ],
          if (patient.medicalHistory.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(patient.medicalHistory,
                style: const TextStyle(color: Clinic.secondary, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Clinic.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Clinic.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Clinic.primary),
          const SizedBox(width: 6),
          Text('$label: ',
              style: TextStyle(
                  color: Clinic.secondary.withValues(alpha: 0.7),
                  fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  color: Clinic.brandNavy,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _recorderCard(AppState state, bool recording) {
    // The WHOLE card is the primary control: tap anywhere to start, and tap
    // anywhere to stop — so mid-visit the clinician never has to aim for a
    // small button. The pause button inside stays its own control: a tap on it
    // wins the gesture arena, so it pauses instead of stopping.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: recording ? () => _stopFromCardTap(state) : _start,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Clinic.cardWhite,
          borderRadius: BorderRadius.circular(Clinic.rCard),
          border: Border.all(
              color: recording
                  ? Clinic.priorityHigh.withValues(alpha: 0.35)
                  : Clinic.borderColor),
          boxShadow: Clinic.cardShadow,
        ),
        child: Column(
          children: [
            Text(
              recording
                  ? _fmt(state.recordingSeconds * 1000)
                  : 'Ready to record',
              style: TextStyle(
                  fontSize: recording ? 54 : 22,
                  fontWeight: FontWeight.bold,
                  color: recording
                      ? (state.isPaused
                          ? Clinic.priorityMedium
                          : Clinic.priorityHigh)
                      : Clinic.secondary),
            ),
            if (recording) ...[
              const SizedBox(height: 8),
              Text(state.isPaused ? 'PAUSED' : 'RECORDING',
                  style: TextStyle(
                      color: state.isPaused
                          ? Clinic.priorityMedium
                          : Clinic.priorityHigh,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.5)),
              const SizedBox(height: 22),
              _waveform(state.recordingLevel, state.isPaused),
            ],
            const SizedBox(height: 28),
            if (!recording)
              _circleButton(
                color: Clinic.primary,
                icon: Icons.mic,
                size: 48,
                onTap: _start,
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _circleButton(
                    color: Clinic.priorityMedium,
                    icon: state.isPaused ? Icons.play_arrow : Icons.pause,
                    size: 34,
                    onTap: () => state.isPaused
                        ? state.resumeRecording()
                        : state.pauseRecording(),
                  ),
                  const SizedBox(width: 36),
                  _circleButton(
                    color: Clinic.priorityHigh,
                    icon: Icons.stop,
                    size: 42,
                    onTap: _stopAndSubmit,
                  ),
                ],
              ),
            const SizedBox(height: 14),
            Text(
              recording
                  ? (state.isPaused
                      ? 'Tap anywhere to stop  ·  play to resume'
                      : 'Tap anywhere to stop  ·  pause below')
                  : 'Tap anywhere to start recording',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Clinic.secondary.withValues(alpha: 0.7), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// Live, flowing waveform that mirrors around the centre line with a
  /// red→blue gradient across the bars. Bar heights respond to the microphone
  /// [level]; the gentle motion comes from [_waveCtrl]. Dims when [paused].
  Widget _waveform(double level, bool paused) {
    const bars = 30;
    const maxH = 82.0;
    final amp = paused ? 0.12 : (0.28 + 0.72 * level.clamp(0.0, 1.0));
    return SizedBox(
      height: maxH,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _waveCtrl,
        builder: (context, _) {
          final phase = _waveCtrl.value * 2 * math.pi;
          // Scale the bar row down if it would be wider than the card, so it
          // never overflows on a narrow screen.
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(bars, (i) {
              // Centre-weighted arch so the wave is tallest in the middle.
              final arch = math.sin(math.pi * (i + 0.5) / bars);
              // Two offset sines give an organic, non-repeating ripple.
              final ripple = 0.5 +
                  0.5 *
                      (0.6 * math.sin(phase + i * 0.55) +
                          0.4 * math.sin(phase * 1.7 + i * 0.3));
              final h = (6.0 + arch * ripple * amp * maxH).clamp(5.0, maxH);
              final color = Color.lerp(
                  Clinic.priorityHigh, Clinic.primary, i / (bars - 1))!;
              return Container(
                width: 5,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: paused ? color.withValues(alpha: 0.35) : color,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          );
        },
      ),
    );
  }

  Widget _circleButton(
      {required Color color,
      required IconData icon,
      required double size,
      required VoidCallback onTap}) {
    return Pressable(
      scale: 0.92,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: size + 4,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: size),
          ),
        ),
      ),
    );
  }

  Widget _recordingsList(AppState state, ClinicalService svc) {
    // Total recordings the SERVER holds for this patient (a visit can hold
    // several). Local files are just the ones captured on THIS device.
    final serverCount = svc.recordedCountForPatient(widget.patientId);
    final localCount = state.recordings.length;
    // Recordings the server has that aren't stored on this device — e.g. made in
    // the web app or on another phone (or the local copy was purged).
    final remoteOnly = (serverCount - localCount).clamp(0, 9999);

    if (localCount == 0) {
      // No local copy on THIS device. If the patient is recorded on the server,
      // say so clearly (with the count) instead of the misleading "no recordings".
      if (serverCount > 0) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_done_outlined,
                    size: 48, color: Clinic.statusActive),
                const SizedBox(height: 14),
                Text(
                    serverCount == 1
                        ? 'Recording uploaded'
                        : '$serverCount recordings uploaded',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Clinic.brandNavy)),
                const SizedBox(height: 6),
                Text(
                    'This visit is "${svc.patientStatusLabel(widget.patientId)}". '
                    'The audio is safely on the server with the scribe — a local '
                    'copy isn\'t kept on this device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Clinic.secondary.withValues(alpha: 0.85),
                        height: 1.4)),
              ],
            ),
          ),
        );
      }
      return Center(
        child: Text('No recordings yet for this patient.',
            style: TextStyle(color: Clinic.secondary.withValues(alpha: 0.7))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      // One row per local recording, plus a trailing note if the server holds
      // additional recordings that aren't on this device.
      itemCount: localCount + (remoteOnly > 0 ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == localCount) return _remoteOnlyNote(remoteOnly);
        final r = state.recordings[i];
        final playing = state.playingPath == r.audioFilePath;
        final ts = DateFormat('MMM d, HH:mm')
            .format(DateTime.fromMillisecondsSinceEpoch(r.timestamp));
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Clinic.cardWhite,
            borderRadius: BorderRadius.circular(Clinic.rCard),
            border: Border.all(color: Clinic.borderColor),
            boxShadow: Clinic.rowShadow,
          ),
          child: Row(
            children: [
              // Every recording is playable — the clinician can replay it to
              // confirm what was captured, even after it's gone to the scribe.
              IconButton(
                onPressed: () => state.playRecording(r.audioFilePath),
                icon: Icon(playing ? Icons.stop_circle : Icons.play_circle_fill,
                    color: Clinic.primary, size: 32),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Clinic.brandNavy)),
                    Row(
                      children: [
                        if (r.isUploaded) ...[
                          const Icon(Icons.cloud_done,
                              size: 13, color: Clinic.statusActive),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            r.isUploaded
                                ? 'Sent to scribe · ${_fmt(r.durationMs)}'
                                : '${_fmt(r.durationMs)} · $ts',
                            style: TextStyle(
                                color: Clinic.secondary.withValues(alpha: 0.7),
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete local copy',
                onPressed: () => state.deleteRecording(r.id),
                icon: const Icon(Icons.delete_outline, color: Clinic.priorityHigh),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Note shown when the server holds more recordings for this visit than are
  /// stored on this device (e.g. captured in the web app or on another phone).
  /// They're safe with the scribe; playback of those lives in the web app.
  Widget _remoteOnlyNote(int count) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Clinic.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Clinic.rCard),
        border: Border.all(color: Clinic.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_done_outlined,
              size: 22, color: Clinic.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              count == 1
                  ? '1 more recording is on the server (made elsewhere) and is '
                      'with the scribe.'
                  : '$count more recordings are on the server (made elsewhere) '
                      'and are with the scribe.',
              style: TextStyle(
                  color: Clinic.secondary.withValues(alpha: 0.9),
                  fontSize: 12,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
