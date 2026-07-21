import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/clinical_models.dart';
import '../services/clinical_service.dart';
import '../theme.dart';
import 'patient_list_screen.dart';
import 'review_queue_screen.dart';

/// Top-level shell: two tabs.
///   • Schedule — the day's patient list (state-coloured cards; record + inline
///     "Review" once the scribe finishes a note).
///   • Notes    — every note grouped date-wise (Today / Yesterday / …), the same
///     date-first way the schedule reads.
///
/// Both children own their own Scaffold; an IndexedStack keeps each tab's
/// scroll position and state alive when switching. A badge on the Notes tab
/// shows how many notes are waiting on the doctor.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<ClinicalService>();
    final toReview = svc.reviewQueue
        .where((v) =>
            v.status == VisitStatus.readyForReview ||
            v.status == VisitStatus.failed)
        .length;

    return Scaffold(
      backgroundColor: Clinic.backgroundLight,
      body: IndexedStack(
        index: _index,
        children: const [
          PatientListScreen(),
          ReviewQueueScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: Clinic.cardWhite,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Clinic.primary.withValues(alpha: 0.14),
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.event_note_outlined, color: Clinic.secondary),
            selectedIcon: Icon(Icons.event_note, color: Clinic.primary),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: _notesIcon(Icons.fact_check_outlined, toReview, false),
            selectedIcon: _notesIcon(Icons.fact_check, toReview, true),
            label: 'Notes',
          ),
        ],
      ),
    );
  }

  /// Notes tab icon with a small count badge when notes await the doctor.
  Widget _notesIcon(IconData icon, int count, bool selected) {
    final base = Icon(icon, color: selected ? Clinic.primary : Clinic.secondary);
    if (count == 0) return base;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        base,
        Positioned(
          right: -6,
          top: -5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 16),
            decoration: BoxDecoration(
              color: Clinic.priorityHigh,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Clinic.cardWhite, width: 1.5),
            ),
            child: Text(
              count > 9 ? '9+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1.1),
            ),
          ),
        ),
      ],
    );
  }
}
