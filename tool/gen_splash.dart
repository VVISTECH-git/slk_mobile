// Splash logo — cream/gold kalamkari diamond on transparent, so it reads on the
// terracotta splash background. Output: assets/icon/splash_logo.png
//   dart run tool/gen_splash.dart
import 'dart:io';
import 'package:image/image.dart' as img;

const int size = 640;
final cream = img.ColorRgb8(0xFB, 0xF6, 0xEF);
final gold = img.ColorRgb8(0xC9, 0xA2, 0x4B);
final terracottaDark = img.ColorRgb8(0x8F, 0x3F, 0x2C);

List<img.Point> diamond(double cx, double cy, double r) => [
      img.Point(cx, cy - r),
      img.Point(cx + r, cy),
      img.Point(cx, cy + r),
      img.Point(cx - r, cy),
    ];

void main() {
  final im = img.Image(width: size, height: size, numChannels: 4);
  img.fill(im, color: img.ColorRgba8(0, 0, 0, 0));
  final c = size / 2.0;
  img.fillPolygon(im, vertices: diamond(c, c, 300), color: cream);
  img.fillPolygon(im, vertices: diamond(c, c, 215), color: terracottaDark);
  img.fillPolygon(im, vertices: diamond(c, c, 150), color: gold);
  img.fillPolygon(im, vertices: diamond(c, c, 78), color: cream);

  Directory('assets/icon').createSync(recursive: true);
  File('assets/icon/splash_logo.png').writeAsBytesSync(img.encodePng(im));
  stdout.writeln('Wrote assets/icon/splash_logo.png');
}
