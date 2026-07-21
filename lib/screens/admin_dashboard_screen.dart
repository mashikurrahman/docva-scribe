import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Surface admin action messages as snackbars.
    final msg = state.adminMessage;
    if (msg != null) {
      state.clearAdminMessage();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      });
    }

    if (!state.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Administration')),
        body: const Center(
          child: Text('Administrator access required.',
              style: TextStyle(
                  color: Clinic.secondary, fontWeight: FontWeight.bold)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Clinic.backgroundLight,
      appBar: AppBar(
        title: const Text('User Administration',
            style: TextStyle(fontWeight: FontWeight.bold, color: Clinic.brandNavy)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Clinic.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('New Account', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddDialog(context, state),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: state.users.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, i) {
          final u = state.users[i];
          final isSelf = u.id == state.currentUser?.id;
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Clinic.surfaceLight,
              borderRadius: BorderRadius.circular(Clinic.rCard),
              border: Border.all(color: Clinic.borderColor),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Clinic.primary.withValues(alpha: 0.12),
                      child: Icon(u.isAdmin ? Icons.star : Icons.person,
                          color: Clinic.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.fullName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Clinic.brandNavy)),
                          Text(u.username,
                              style: TextStyle(
                                  color: Clinic.secondary.withValues(alpha: 0.7),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    _RoleBadge(isAdmin: u.isAdmin),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Clinic.primary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Clinic.rControl)),
                        ),
                        icon: const Icon(Icons.lock_reset,
                            size: 18, color: Clinic.primary),
                        label: const Text('Reset Password',
                            style: TextStyle(
                                color: Clinic.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        onPressed: () => _showResetDialog(context, state, u),
                      ),
                    ),
                    if (!isSelf) ...[
                      const SizedBox(width: 10),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Clinic.priorityHigh),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Clinic.rControl)),
                        ),
                        onPressed: () => _confirmDelete(context, state, u),
                        child: const Icon(Icons.delete_outline,
                            size: 18, color: Clinic.priorityHigh),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddDialog(BuildContext context, AppState state) {
    final user = TextEditingController();
    final name = TextEditingController();
    final pass = TextEditingController();
    bool admin = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Clinic.cardWhite,
          title: const Text('New account',
              style: TextStyle(fontWeight: FontWeight.bold, color: Clinic.brandNavy)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(name, 'Full name'),
              const SizedBox(height: 10),
              _dialogField(user, 'Username / email'),
              const SizedBox(height: 10),
              _dialogField(pass, 'Initial password'),
              const SizedBox(height: 4),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: Clinic.primary,
                value: admin,
                onChanged: (v) => setLocal(() => admin = v ?? false),
                title: const Text('Grant administrator privileges',
                    style: TextStyle(fontSize: 14, color: Clinic.secondary)),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Clinic.secondary))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Clinic.primary),
              onPressed: () {
                state.adminCreateAccount(
                    user.text, name.text, pass.text, admin ? 'admin' : 'clinician');
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context, AppState state, User u) {
    final pass = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Clinic.cardWhite,
        title: const Text('Reset password',
            style: TextStyle(fontWeight: FontWeight.bold, color: Clinic.brandNavy)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Set a new password for ${u.fullName} (${u.username}).',
                style: TextStyle(
                    fontSize: 13, color: Clinic.secondary.withValues(alpha: 0.7))),
            const SizedBox(height: 12),
            _dialogField(pass, 'New password'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Clinic.secondary))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Clinic.primary),
            onPressed: () {
              state.adminResetPassword(u.id, pass.text);
              Navigator.pop(ctx);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState state, User u) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Clinic.cardWhite,
        title: const Text('Remove account',
            style: TextStyle(fontWeight: FontWeight.bold, color: Clinic.brandNavy)),
        content: Text(
            'Delete the account for ${u.fullName} (${u.username})? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Clinic.secondary))),
          TextButton(
            onPressed: () {
              state.adminDeleteAccount(u.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: Clinic.priorityHigh, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(TextEditingController c, String label) => TextField(
        controller: c,
        style: const TextStyle(color: Clinic.secondary),
        decoration: InputDecoration(
          labelText: label,
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Clinic.rControl),
              borderSide: const BorderSide(color: Clinic.outlineColor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Clinic.rControl),
              borderSide: const BorderSide(color: Clinic.primary, width: 2)),
        ),
      );
}

class _RoleBadge extends StatelessWidget {
  final bool isAdmin;
  const _RoleBadge({required this.isAdmin});
  @override
  Widget build(BuildContext context) {
    final color = isAdmin ? Clinic.brandNavy : Clinic.statusActive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Clinic.rChip),
          border: Border.all(color: color.withValues(alpha: 0.40))),
      child: Text(isAdmin ? 'ADMIN' : 'CLINICIAN',
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.5)),
    );
  }
}
