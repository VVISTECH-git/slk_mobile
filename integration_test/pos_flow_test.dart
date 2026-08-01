// Read-only end-to-end smoke test of the POS flow against the LIVE API.
// Drives: login (Owner / PIN 1111 / Retail Unit 1) → home → open POS → verify a
// product list loads. It deliberately stops BEFORE completing a sale, so it
// never writes an invoice or moves stock.
//
// Run on a booted emulator/device:
//   flutter test integration_test/pos_flow_test.dart -d <deviceId>
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:slk_mobile/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Pump repeatedly until [finder] matches or the timeout elapses (handles
  // network waits without a fixed sleep). Exception-safe so composite finders
  // like `.last` don't blow up while the target hasn't rendered yet.
  Future<void> waitFor(WidgetTester tester, Finder finder,
      {Duration timeout = const Duration(seconds: 45)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 400));
      try {
        if (finder.evaluate().isNotEmpty) return;
      } catch (_) {
        // finder not resolvable yet — keep polling
      }
    }
    throw TestFailure('Timed out waiting for: $finder');
  }

  testWidgets('login → POS loads products (read-only)', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SlkApp()));

    // Login form loads its staff options from the API.
    await waitFor(tester, find.text('Sign in to the till'));

    // Pick the staff member (item text is "Owner  ·  Owner": name + role).
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await waitFor(tester, find.textContaining('Owner'));
    await tester.tap(find.textContaining('Owner').last);
    await tester.pumpAndSettle();

    // Owner has no fixed store → a store picker appears; choose Retail Unit 1.
    await waitFor(tester, find.text('Operate at store'));
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('Retail Unit 1'));
    await tester.tap(find.text('Retail Unit 1').last);
    await tester.pumpAndSettle();

    // Enter the PIN and sign in.
    await tester.enterText(find.byType(TextField).last, '1111');
    await tester.tap(find.text('Sign in'));

    // Land on the home hub, then open POS.
    await waitFor(tester, find.text('Point of Sale'));
    await tester.tap(find.text('Point of Sale'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('Search product or SKU'));

    // A real product from the live store should render (SKUs start "SLK-").
    await waitFor(tester, find.textContaining('SLK-'));
    expect(find.textContaining('SLK-'), findsWidgets);
  });
}
