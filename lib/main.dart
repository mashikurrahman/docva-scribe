import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'api/api_config.dart';
import 'api/token_store.dart';
import 'services/clinical_service.dart';
import 'services/connectivity_service.dart';
import 'services/notification_service.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  // Guard the entire startup so a failure in any single init step can never
  // leave the app on a blank white screen. If something throws, we still get
  // into the UI (degraded) and — on a non-release build — surface the actual
  // error so it can be diagnosed (e.g. on a simulator / Appetize).
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final startupErrors = <String>[];

    // The foreground-service comm port is Android-centric; never let it block
    // launch (it's not needed until a recording starts).
    try {
      FlutterForegroundTask.initCommunicationPort();
    } catch (e) {
      startupErrors.add('foreground task: $e');
    }

    final tokens = TokenStore();
    final connectivity = ConnectivityService();
    late final ClinicalService clinical;

    // Each step is individually guarded: one failing dependency (DB, secure
    // storage, connectivity) must not stop the app from reaching the login UI.
    try {
      await ApiConfig.load();
    } catch (e) {
      startupErrors.add('config: $e');
    }
    try {
      await tokens.load();
    } catch (e) {
      startupErrors.add('tokens: $e');
    }
    try {
      await connectivity.init();
    } catch (e) {
      startupErrors.add('connectivity: $e');
    }
    // Local notifications (recording uploaded / note ready). Fire-and-forget —
    // the plugin init must never delay launch, and it swallows its own errors.
    unawaited(NotificationService.instance.init());

    clinical = ClinicalService(connectivity: connectivity, tokens: tokens);
    try {
      await clinical.init();
    } catch (e, st) {
      startupErrors.add('clinical: $e');
      debugPrint('CLINICAL INIT FAILED: $e\n$st');
    }

    if (startupErrors.isNotEmpty) {
      debugPrint('STARTUP ERRORS:\n${startupErrors.join('\n')}');
    }

    final state = AppState(clinical: clinical, tokens: tokens);
    // Credentials-first launch: the app always opens to the login screen. The
    // clinician signs in with their email + password; the biometric / Face ID
    // check then runs as a second factor right after sign-in (see RootGate).
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: state),
          ChangeNotifierProvider.value(value: clinical),
        ],
        // On a debug build, if startup hit problems, show them on top of the
        // app so they're visible on a simulator with no log access.
        child: AnotApp(
          startupError:
              (kReleaseMode || startupErrors.isEmpty)
                  ? null
                  : startupErrors.join('\n'),
        ),
      ),
    );
  }, (error, stack) {
    // Last-resort handler: paint the error instead of a blank screen.
    debugPrint('UNCAUGHT STARTUP ERROR: $error\n$stack');
    runApp(_StartupErrorApp(message: '$error'));
  });
}

/// Shown only if startup completely fails — guarantees the screen is never a
/// silent blank, so the failure is diagnosable on a device/simulator.
class _StartupErrorApp extends StatelessWidget {
  final String message;
  const _StartupErrorApp({required this.message});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B1B2B),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Startup failed',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(message,
                        style: const TextStyle(
                            color: Color(0xFFFFB4A2), fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnotApp extends StatefulWidget {
  final String? startupError;
  const AnotApp({super.key, this.startupError});
  @override
  State<AnotApp> createState() => _AnotAppState();
}

class _AnotAppState extends State<AnotApp> {
  @override
  void initState() {
    super.initState();
    final err = widget.startupError;
    if (err != null) {
      // Surface non-fatal startup problems once the first frame is up, so a
      // simulator with no log access still shows what went wrong.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 12),
            backgroundColor: const Color(0xFF7A1F1F),
            content: Text('Startup issue: $err',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DOCVA',
      debugShowCheckedModeBanner: false,
      theme: buildAnotTheme(),
      // Any pointer interaction resets the HIPAA automatic-logoff countdown.
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => context.read<AppState>().registerActivity(),
        child: _RecordingOverlay(child: child ?? const SizedBox.shrink()),
      ),
      home: const _BootGate(),
    );
  }
}

/// Shows the branded splash animation first, then cross-fades to the real app
/// (login / home). The splash is cosmetic; startup work already ran in `main()`.
class _BootGate extends StatefulWidget {
  const _BootGate();
  @override
  State<_BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<_BootGate> {
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _ready
          ? const RootGate()
          : SplashScreen(onDone: () {
              if (mounted) setState(() => _ready = true);
            }),
    );
  }
}

/// App-wide "● Recording mm:ss" banner shown above everything while a recording
/// is in progress, so the clinician always knows capture is live — even after
/// navigating away from the visit screen.
class _RecordingOverlay extends StatelessWidget {
  final Widget child;
  const _RecordingOverlay({required this.child});

  @override
  Widget build(BuildContext context) {
    final recording = context.select<AppState, bool>((s) => s.isRecording);
    if (!recording) return child;
    final secs = context.select<AppState, int>((s) => s.recordingSeconds);
    final paused = context.select<AppState, bool>((s) => s.isPaused);
    final mm = (secs ~/ 60).toString().padLeft(2, '0');
    final ss = (secs % 60).toString().padLeft(2, '0');
    return Column(
      children: [
        Material(
          color: paused ? Clinic.priorityMedium : Clinic.priorityHigh,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(
                      paused
                          ? Icons.pause_circle_filled
                          : Icons.fiber_manual_record,
                      color: Colors.white,
                      size: 16),
                  const SizedBox(width: 8),
                  Text(paused ? 'Recording paused' : 'Recording',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const Spacer(),
                  Text('$mm:$ss',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFeatures: [FontFeature.tabularFigures()])),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Routes between login, the biometric PHI-vault lock, and the app.
class RootGate extends StatelessWidget {
  const RootGate({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.currentUser == null) return const LoginScreen();
    if (!state.biometricUnlocked) return const VaultLockScreen();
    // First-login tour (one time), shown inside the authenticated boundary.
    if (state.needsOnboarding) return const OnboardingScreen();
    return const HomeShell();
  }
}

class VaultLockScreen extends StatefulWidget {
  const VaultLockScreen({super.key});
  @override
  State<VaultLockScreen> createState() => _VaultLockScreenState();
}

class _VaultLockScreenState extends State<VaultLockScreen> {
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().unlockVault();
    });
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    setState(() => _verifying = true);
    await context.read<AppState>().unlockVaultWithPassword(_passwordCtrl.text);
    if (mounted) setState(() => _verifying = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final showPwField = _showPassword || !state.biometricAvailable;

    return Scaffold(
      backgroundColor: Clinic.backgroundLight,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 64, color: Clinic.primary),
              const SizedBox(height: 16),
              const Text('PHI VAULT LOCKED',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: Clinic.brandNavy)),
              const SizedBox(height: 8),
              const Text('Verify your identity to access patient records.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Clinic.secondary)),
              if (state.vaultError != null) ...[
                const SizedBox(height: 12),
                Text(state.vaultError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Clinic.priorityHigh,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ],
              const SizedBox(height: 24),
              if (state.biometricAvailable)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Clinic.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14)),
                  onPressed: () => context.read<AppState>().unlockVault(),
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('UNLOCK WITH BIOMETRICS'),
                ),
              if (showPwField) ...[
                const SizedBox(height: 18),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submitPassword(),
                  decoration: InputDecoration(
                    labelText: 'Account password',
                    filled: true,
                    fillColor: Clinic.cardWhite,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Clinic.brandNavy,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _verifying ? null : _submitPassword,
                    child: Text(_verifying ? 'Verifying…' : 'UNLOCK WITH PASSWORD'),
                  ),
                ),
              ] else
                TextButton(
                  onPressed: () => setState(() => _showPassword = true),
                  child: const Text('Use password instead',
                      style: TextStyle(color: Clinic.secondary)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
