import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// HIPAA audit-controls viewer: a read-only trail of access and admin events.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});
  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  late Future<List<AuditEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().loadAuditLogs();
  }

  void _reload() {
    setState(() => _future = context.read<AppState>().loadAuditLogs());
  }

  Color _actionColor(String a) {
    if (a.contains('FAILURE') || a.contains('DELETE')) return Clinic.priorityHigh;
    if (a.startsWith('ADMIN') || a.contains('AUTO_LOGOFF')) return Clinic.priorityMedium;
    return Clinic.statusActive;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Clinic.backgroundLight,
      appBar: AppBar(
        title: const Text('Audit Trail',
            style: TextStyle(fontWeight: FontWeight.bold, color: Clinic.brandNavy)),
        actions: [
          IconButton(
              onPressed: _reload,
              icon: const Icon(Icons.refresh, color: Clinic.primary)),
        ],
      ),
      body: FutureBuilder<List<AuditEntry>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final logs = snap.data!;
          if (logs.isEmpty) {
            return const Center(
                child: Text('No audit events recorded yet.',
                    style: TextStyle(color: Clinic.secondary)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final e = logs[i];
              final ts = DateFormat('MMM d, HH:mm:ss')
                  .format(DateTime.fromMillisecondsSinceEpoch(e.timestamp));
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Clinic.cardWhite,
                  borderRadius: BorderRadius.circular(Clinic.rControl),
                  border: Border.all(color: Clinic.borderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6, right: 12),
                      decoration: BoxDecoration(
                          color: _actionColor(e.action), shape: BoxShape.circle),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.action,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _actionColor(e.action),
                                  fontSize: 13)),
                          if (e.details.isNotEmpty)
                            Text(e.details,
                                style: const TextStyle(
                                    color: Clinic.secondary, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text('${e.clinicianName} · $ts',
                              style: TextStyle(
                                  color: Clinic.secondary.withValues(alpha: 0.6),
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
