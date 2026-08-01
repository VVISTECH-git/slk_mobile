import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';
import 'api_client.dart';

/// The shared API client. On a 401 it drives the auth controller to sign out,
/// which the router turns into a redirect back to the login screen.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    onUnauthorized: () {
      // Fire-and-forget; guard against disposal during teardown.
      try {
        ref.read(authControllerProvider.notifier).signOut();
      } catch (_) {}
    },
  );
});
