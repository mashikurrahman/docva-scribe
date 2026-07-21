import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/clinical_service.dart';
import '../theme.dart';

/// Clinician profile: identity, role, and security posture.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser;

    return Scaffold(
      backgroundColor: Clinic.backgroundLight,
      appBar: AppBar(
        title: const Text('My Profile',
            style: TextStyle(fontWeight: FontWeight.bold, color: Clinic.brandNavy)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Clinic.primary.withValues(alpha: 0.12),
                  child: Text(
                    (user?.fullName.isNotEmpty ?? false) ? user!.fullName[0] : '?',
                    style: const TextStyle(
                        fontSize: 34, color: Clinic.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text(user?.fullName ?? 'Clinician',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: Clinic.brandNavy)),
                Text(user?.username ?? '',
                    style: TextStyle(color: Clinic.secondary.withValues(alpha: 0.7))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _section('CLINICAL SPECIALTY', Icons.star, [
            _row('Primary Department', user?.role == 'admin' ? 'Administration' : 'Primary Care'),
            _row('Credential Level', user?.role == 'admin' ? 'System Administrator' : 'MD / Senior Resident'),
          ]),
          const SizedBox(height: 14),
          _section('SECURITY', Icons.shield, [
            _row('Account role', user?.role ?? 'clinician'),
            _row('Biometric vault', 'Enabled'),
            _row('Auto-logoff', '${AppState.inactivityTimeout.inMinutes} min inactivity'),
            _row('Password storage', 'PBKDF2 (hashed)'),
          ]),
          const SizedBox(height: 24),
          // Settings live in the web app for clinicians — there's no Settings
          // anywhere in this app.
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Clinic.priorityHigh),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Clinic.rControl)),
              ),
              onPressed: () {
                // Purge in-memory PHI from both stores on sign-out.
                context.read<ClinicalService>().clearForLogout();
                state.logout();
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              icon: const Icon(Icons.logout, color: Clinic.priorityHigh),
              label: const Text('Sign Out Securely',
                  style: TextStyle(color: Clinic.priorityHigh, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
          // No Settings anywhere in the clinician app — all configuration lives
          // in the web app. Just the version label.
          Center(
            child: Text('DOCVA · v1.0',
                style: TextStyle(
                    color: Clinic.secondary.withValues(alpha: 0.45),
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Clinic.surfaceLight,
          borderRadius: BorderRadius.circular(Clinic.rCard),
          border: Border.all(color: Clinic.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: Clinic.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Clinic.accentDarkPurple, fontSize: 13)),
            ]),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Clinic.secondary.withValues(alpha: 0.7), fontSize: 13)),
            Text(value,
                style: const TextStyle(color: Clinic.brandNavy, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );
}
