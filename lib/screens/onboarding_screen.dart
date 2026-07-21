import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../logo.dart';
import '../theme.dart';

/// A short, one-time tour shown to a doctor on their first login (and replayable
/// from Settings). Explains the whole workflow in four plain steps:
/// Add patient → Record → Review note. Contains NO patient data.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Slide {
  final IconData? icon;
  final bool showLogo;
  final String title;
  final String body;
  const _Slide(
      {this.icon,
      this.showLogo = false,
      required this.title,
      required this.body});
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _slides = <_Slide>[
    _Slide(
      showLogo: true,
      title: 'Welcome to DOCVA',
      body:
          'Your simple, secure companion for capturing patient visits and reviewing notes.',
    ),
    _Slide(
      icon: Icons.person_add_alt_1,
      title: '1  ·  Add your patient',
      body:
          'Tap “Add patient”, then enter their name, MRN and visit time. They show up on that day’s list.',
    ),
    _Slide(
      icon: Icons.mic_none,
      title: '2  ·  Record the visit',
      body:
          'Open the patient and tap Record. The audio is encrypted on your phone and sent securely to your scribe.',
    ),
    _Slide(
      icon: Icons.fact_check_outlined,
      title: '3  ·  Review the note',
      body:
          'When your scribe finishes, the note appears in the Notes tab. Edit it, request changes, or approve as final.',
    ),
  ];

  void _finish() {
    context.read<AppState>().completeOnboarding();
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  void _next() {
    if (_index < _slides.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _slides.length - 1;
    return Scaffold(
      backgroundColor: Clinic.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: last
                    ? null
                    : TextButton(
                        onPressed: _finish,
                        child: const Text('Skip',
                            style: TextStyle(color: Clinic.secondary)),
                      ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _slideView(_slides[i]),
              ),
            ),
            _dots(),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Clinic.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Clinic.rControl)),
                  ),
                  onPressed: _next,
                  child: Text(last ? 'Get started' : 'Next',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slideView(_Slide s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (s.showLogo)
            const AnotLogo(height: 120)
          else
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Clinic.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(s.icon, size: 56, color: Clinic.primary),
            ),
          const SizedBox(height: 32),
          Text(s.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Clinic.brandNavy)),
          const SizedBox(height: 14),
          Text(s.body,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Clinic.secondary.withValues(alpha: 0.85))),
        ],
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slides.length, (i) {
        final active = i == _index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? Clinic.primary : Clinic.borderColor,
            borderRadius: BorderRadius.circular(Clinic.rChip),
          ),
        );
      }),
    );
  }
}
