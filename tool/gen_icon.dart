// Generates the app-icon PNGs from code (no design tool needed):
//   assets/icon/app_icon.png     — terracotta background + cream block-print motif
//   assets/icon/app_icon_fg.png  — transparent background + motif (adaptive fg)
//
// Run:  dart run tool/gen_icon.dart   then   dart run flutter_launcher_icons
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

const int size = 1024;
final terracotta = img.ColorRgb8(0xB5, 0x53, 0x3B);
final cream = img.ColorRgb8(0xFB, 0xF6, 0xEF);
final gold = img.ColorRgb8(0xC9, 0xA2, 0x4B);

// A diamond (rotated square) of half-diagonal [r] centred on the canvas.
List<img.Point> diamond(double cx, double cy, double r) => [
      img.Point(cx, cy - r),
      img.Point(cx + r, cy),
      img.Point(cx, cy + r),
      img.Point(cx - r, cy),
    ];

void drawMotif(img.Image im) {
  final c = size / 2.0;
  // Concentric block-print diamonds — a nod to kalamkari stamp motifs.
  img.fillPolygon(im, vertices: diamond(c, c, 300), color: cream);
  img.fillPolygon(im, vertices: diamond(c, c, 210), color: terracotta);
  img.fillPolygon(im, vertices: diamond(c, c, 140), color: gold);
  img.fillPolygon(im, vertices: diamond(c, c, 70), color: cream);
  // Four corner dots.
  for (final a in [45, 135, 225, 315]) {
    final rad = a * math.pi / 180;
    img.fillCircle(im,
        x: (c + 360 * math.cos(rad)).round(),
        y: (c + 360 * math.sin(rad)).round(),
        radius: 26,
        color: cream);
  }
}

void main() {
  Directory('assets/icon').createSync(recursive: true);

  // Full icon (terracotta background).
  final full = img.Image(width: size, height: size);
  img.fill(full, color: terracotta);
  drawMotif(full);
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(full));

  // Adaptive foreground (transparent background, motif kept within safe zone).
  final fg = img.Image(width: size, height: size, numChannels: 4);
  img.fill(fg, color: img.ColorRgba8(0, 0, 0, 0));
  drawMotif(fg);
  File('assets/icon/app_icon_fg.png').writeAsBytesSync(img.encodePng(fg));

  stdout.writeln('Wrote assets/icon/app_icon.png and app_icon_fg.png');
}
