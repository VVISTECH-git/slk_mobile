// Resizes the raw captured screenshots to the exact App Store size (1284x2778)
// on a clean cream canvas. Output: store/screenshots/*.png
//   dart run tool/frame_screenshots.dart
import 'dart:io';
import 'package:image/image.dart' as img;

const int W = 1284;
const int H = 2778;
final cream = img.ColorRgb8(0xFB, 0xF6, 0xEF);

void main() {
  final srcDir = Directory('screenshots');
  final outDir = Directory('store/screenshots')..createSync(recursive: true);

  final files = srcDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.png'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final f in files) {
    final src = img.decodePng(f.readAsBytesSync());
    if (src == null) continue;

    // Scale to fit within the target while preserving aspect ratio.
    final scale = (W / src.width) < (H / src.height) ? W / src.width : H / src.height;
    final rw = (src.width * scale).round();
    final rh = (src.height * scale).round();
    final resized = img.copyResize(src, width: rw, height: rh, interpolation: img.Interpolation.cubic);

    // Center on a cream canvas of the exact required size.
    final canvas = img.Image(width: W, height: H);
    img.fill(canvas, color: cream);
    img.compositeImage(canvas, resized, dstX: ((W - rw) / 2).round(), dstY: ((H - rh) / 2).round());

    final name = f.uri.pathSegments.last;
    File('${outDir.path}/$name').writeAsBytesSync(img.encodePng(canvas));
    stdout.writeln('framed $name  (${src.width}x${src.height} -> ${W}x$H)');
  }
}
