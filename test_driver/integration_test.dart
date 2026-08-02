// Driver for the screenshot integration test. Receives each screenshot's bytes
// from the on-device test and writes them to screenshots/<name>.png.
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshots_test.dart -d <device>
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final dir = Directory('screenshots');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      File('screenshots/$name.png').writeAsBytesSync(bytes);
      return true;
    },
  );
}
