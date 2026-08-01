// Generates Google Play store graphics from the brand palette:
//   store_assets/play_icon_512.png       — 512x512 app icon (Play requirement)
//   store_assets/play_feature_1024x500.png — 1024x500 feature graphic
//
// Run:  dart run tool/gen_store_assets.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

final terracotta = img.ColorRgb8(0xB5, 0x53, 0x3B);
final terracottaDark = img.ColorRgb8(0x8F, 0x3F, 0x2C);
final cream = img.ColorRgb8(0xFB, 0xF6, 0xEF);
final gold = img.ColorRgb8(0xC9, 0xA2, 0x4B);

List<img.Point> diamond(double cx, double cy, double r) => [
      img.Point(cx, cy - r),
      img.Point(cx + r, cy),
      img.Point(cx, cy + r),
      img.Point(cx - r, cy),
    ];

void motif(img.Image im, double cx, double cy, double s) {
  img.fillPolygon(im, vertices: diamond(cx, cy, 1.5 * s), color: cream);
  img.fillPolygon(im, vertices: diamond(cx, cy, 1.05 * s), color: terracotta);
  img.fillPolygon(im, vertices: diamond(cx, cy, 0.7 * s), color: gold);
  img.fillPolygon(im, vertices: diamond(cx, cy, 0.35 * s), color: cream);
}

void main() {
  Directory('store_assets').createSync(recursive: true);

  // ---- 512 icon: resize the 1024 master (crisp) ----
  final master = img.decodePng(File('assets/icon/app_icon.png').readAsBytesSync())!;
  final icon = img.copyResize(master, width: 512, height: 512, interpolation: img.Interpolation.average);
  File('store_assets/play_icon_512.png').writeAsBytesSync(img.encodePng(icon));

  // ---- 1024x500 feature graphic ----
  final fg = img.Image(width: 1024, height: 500);
  img.fill(fg, color: terracotta);
  // Faint block-print diamond band across the top and bottom.
  for (double x = 60; x < 1024; x += 120) {
    img.fillPolygon(fg, vertices: diamond(x, 40, 26), color: terracottaDark);
    img.fillPolygon(fg, vertices: diamond(x, 460, 26), color: terracottaDark);
  }
  // Big central motif on the left.
  motif(fg, 250, 250, 130);
  // A cream "SLK" block on the right as a clean brand mark (drawn as bars).
  final letters = 620.0;
  img.fillRect(fg, x1: letters.toInt(), y1: 200, x2: (letters + 300).toInt(), y2: 210, color: cream);
  img.fillRect(fg, x1: letters.toInt(), y1: 300, x2: (letters + 220).toInt(), y2: 310, color: gold);
  // (Play lets you overlay the real logo/text later in a design tool.)
  math.Random(); // no-op to keep import
  File('store_assets/play_feature_1024x500.png').writeAsBytesSync(img.encodePng(fg));

  stdout.writeln('Wrote store_assets/play_icon_512.png and play_feature_1024x500.png');
}
