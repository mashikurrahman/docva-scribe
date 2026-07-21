import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// DOCVA "Sharp Tech" header: a flat deep-navy band with a hard bottom edge and
/// a crisp electric-blue accent rule — a product/console feel, deliberately
/// unlike a soft rounded Material app-bar. Put it as the first child of a body
/// [Column]; the band fills behind the status bar and keeps clear of the notch.
class AnotHeader extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const AnotHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 16, 20),
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        decoration: const BoxDecoration(
          gradient: Clinic.headerGradient,
          // Hard bottom edge + electric-blue accent rule.
          border: Border(
            bottom: BorderSide(color: Clinic.primary, width: 3),
          ),
        ),
        child: Stack(
          children: [
            // Subtle geometric accent: a faint blue chevron echoing the mark's
            // arrow, drifting off the top-right. Structural, not decorative.
            Positioned.fill(
              child: CustomPaint(painter: _ChevronAccentPainter()),
            ),
            SafeArea(
              bottom: false,
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// A squared translucent icon button for header actions (refresh, etc.).
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  const HeaderIconButton(
      {super.key, required this.icon, this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Clinic.rControl),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
    );
    final btn = Material(
      color: Colors.white.withValues(alpha: 0.10),
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Draws faint, hard-edged chevrons ">" (the DOCVA arrow motif) in the header
/// background — a quiet tech texture rather than a soft clinical heartbeat.
class _ChevronAccentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter;

    // A few stacked chevrons anchored to the top-right corner.
    final cx = size.width - 26.0;
    final cy = 18.0;
    for (var i = 0; i < 3; i++) {
      final o = i * 26.0;
      final path = Path()
        ..moveTo(cx - 46 - o, cy)
        ..lineTo(cx - o, cy + 46)
        ..lineTo(cx - 46 - o, cy + 92);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
