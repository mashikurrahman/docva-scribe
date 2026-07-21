// One-off: convert the official WebP logo into the PNGs the app uses.
//   assets/images/anot_logo.png  -> full transparent lockup (login screen)
//   assets/images/anot_icon.png  -> 1024x1024 white square, logo centered
//                                   (source for the launcher icon)
// Run: dart run tool/convert_logo.dart
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodeWebP(File('assets/images/anot_logo.webp').readAsBytesSync());
  if (src == null) {
    stderr.writeln('Could not decode assets/images/anot_logo.webp');
    exit(1);
  }

  // 1) Full logo as a transparent PNG for the in-app logo widget.
  File('assets/images/anot_logo.png').writeAsBytesSync(img.encodePng(src));

  // 2) Round launcher-icon source: white disc (transparent outside the circle)
  // with the logo centered, so the icon is round on any launcher.
  const size = 1024;
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fillCircle(canvas,
      x: size ~/ 2,
      y: size ~/ 2,
      radius: size ~/ 2,
      color: img.ColorRgba8(255, 255, 255, 255));

  // Scale the (wide) logo to fit comfortably inside the circle.
  final maxEdge = (size * 0.58).round();
  var scale = maxEdge / src.width;
  if (src.height * scale > maxEdge) scale = maxEdge / src.height;
  final w = (src.width * scale).round();
  final h = (src.height * scale).round();
  final resized = img.copyResize(src,
      width: w, height: h, interpolation: img.Interpolation.cubic);
  img.compositeImage(canvas, resized,
      dstX: ((size - w) / 2).round(), dstY: ((size - h) / 2).round());
  File('assets/images/anot_icon.png').writeAsBytesSync(img.encodePng(canvas));

  stdout.writeln('OK: ${src.width}x${src.height} -> anot_logo.png + round anot_icon.png');
}
