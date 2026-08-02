// Drives the app through its key screens and captures a screenshot of each,
// against the LIVE API (read-only navigation; it does NOT complete a sale).
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshots_test.dart -d <deviceId>
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:slk_mobile/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitFor(WidgetTester tester, Finder finder,
      {Duration timeout = const Duration(seconds: 60)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 400));
      try {
        if (finder.evaluate().isNotEmpty) return;
      } catch (_) {}
    }
    throw TestFailure('Timed out waiting for: $finder');
  }

  // Open a module from the home hub, run [after] once it's loaded, screenshot,
  // then return to the hub. Failures are swallowed so one bad screen doesn't
  // abort the whole run.
  Future<void> capture(
    WidgetTester tester,
    String tile,
    String name,
    Finder readyWhen, {
    Future<void> Function()? after,
  }) async {
    try {
      await tester.tap(find.text(tile).first);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      await waitFor(tester, readyWhen);
      if (after != null) await after();
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await binding.takeScreenshot(name);
      await tester.pageBack();
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
    } catch (e) {
      // Best effort — continue with the next screen.
      // ignore: avoid_print
      print('Screenshot "$name" skipped: $e');
    }
  }

  testWidgets('capture App Store screenshots', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SlkApp()));

    // ---- Login (Owner / Retail Unit 1 / PIN 1111) ----
    await waitFor(tester, find.text('Sign in to the till'));
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await waitFor(tester, find.textContaining('Owner'));
    await tester.tap(find.textContaining('Owner').last);
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('Operate at store'));
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('Retail Unit 1'));
    await tester.tap(find.text('Retail Unit 1').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '1111');
    await tester.tap(find.text('Sign in'));

    // ---- Home hub ----
    await waitFor(tester, find.text('Point of Sale'));
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await binding.takeScreenshot('01_home');

    // ---- POS (add one item so the cart bar shows) ----
    await capture(tester, 'Point of Sale', '02_pos', find.text('Search product or SKU'),
        after: () async {
      final add = find.text('Add');
      if (add.evaluate().isNotEmpty) {
        await tester.tap(add.first);
        await tester.pumpAndSettle(const Duration(milliseconds: 400));
      }
    });

    // ---- Dashboard ----
    await capture(tester, 'Dashboard', '03_dashboard', find.text('Stock by location'));

    // ---- Stock ----
    await capture(tester, 'Stock', '04_stock', find.text('Search stock'));

    // ---- Invoices ----
    await capture(tester, 'Invoices', '05_invoices', find.textContaining('invoices'));

    // ---- Daily report ----
    await capture(tester, 'Daily report', '06_report', find.text('Payment split'));
  });
}
