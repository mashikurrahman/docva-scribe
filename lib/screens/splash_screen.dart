import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logo.dart';
import '../theme.dart';

/// Branded startup animation: the DOCVA mark springs in over a soft
/// gradient while pulse rings ripple outward (echoing the heartbeat brand mark),
/// with a row of breathing dots below. Purely cosmetic — it displays for a short
/// minimum time, then [onDone] fires so the app can cross-fade to the real UI.
class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  final Duration minDuration;
  const SplashScreen({
    super.key,
    required this.onDone,
    this.minDuration = const Duration(milliseconds: 2000),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Intro: fade + spring-scale the logo in once.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();
  // Pulse: continuous ripple + gentle "breathe" of the logo.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
  );
  late final Animation<double> _scale = Tween(begin: 0.72, end: 1.0).animate(
    CurvedAnimation(parent: _intro, curve: Curves.easeOutBack),
  );

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.minDuration, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Clinic.surfaceLight],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_pulse, _intro]),
                    builder: (context, _) {
                      final breathe =
                          1.0 + 0.025 * math.sin(_pulse.value * 2 * math.pi);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          _ring(_pulse.value),
                          _ring((_pulse.value + 0.5) % 1.0),
                          Opacity(
                            opacity: _fade.value.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: _scale.value * breathe,
                              child:
                                  const AnotLogo(height: 104, showWordmark: true),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),
                _LoadingDots(controller: _pulse),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One expanding, fading ring. [t] in 0..1 drives its radius and opacity.
  Widget _ring(double t) {
    final size = 96.0 + t * 128.0;
    final opacity = (1.0 - t) * 0.30 * _fade.value.clamp(0.0, 1.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Clinic.primary.withValues(alpha: opacity),
          width: 2.5,
        ),
      ),
    );
  }
}

/// Three dots that "breathe" in sequence, driven by the shared pulse controller.
class _LoadingDots extends StatelessWidget {
  final Animation<double> controller;
  const _LoadingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Stagger each dot a third of a cycle apart.
            final phase = (controller.value + i / 3) % 1.0;
            final v = (math.sin(phase * 2 * math.pi) + 1) / 2; // 0..1
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Clinic.primary.withValues(alpha: 0.35 + 0.55 * v),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
