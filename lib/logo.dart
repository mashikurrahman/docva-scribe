import 'package:flutter/material.dart';
import 'theme.dart';

/// Displays the official DOCVA logo lockup from assets, with a branded
/// text fallback so the UI still looks correct if the PNG is missing.
class AnotLogo extends StatelessWidget {
  final double height;
  final bool showWordmark;

  /// Use the white knockout lockup — for placement on the coloured gradient
  /// header where the navy/blue logo would not read.
  final bool white;
  const AnotLogo({
    super.key,
    this.height = 96,
    this.showWordmark = true,
    this.white = false,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      white
          ? 'assets/images/docva_logo_white.png'
          : 'assets/images/docva_logo.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => _Fallback(height: height),
    );
  }
}

/// "DOCVA" wordmark fallback — navy with the electric-blue "A" accent.
class _Fallback extends StatelessWidget {
  final double height;
  const _Fallback({required this.height});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: height * 0.5,
          fontWeight: FontWeight.w800,
          letterSpacing: height * 0.03,
        ),
        children: const [
          TextSpan(text: 'DOCV', style: TextStyle(color: Clinic.brandNavy)),
          TextSpan(text: 'A', style: TextStyle(color: Clinic.primary)),
        ],
      ),
    );
  }
}
