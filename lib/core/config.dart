/// App-wide configuration.
///
/// The API base URL is compile-time overridable so the same build can point at
/// local dev, staging or production:
///
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
///   (10.0.2.2 is the host machine's localhost from the Android emulator)
///
/// Defaults to the live Vercel deployment (always-on, no cold starts) so a
/// fresh checkout runs immediately.
class Config {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tantu-store.vercel.app',
  );

  /// All mobile endpoints live under /api/v1.
  static String get apiRoot => '$apiBaseUrl/api/v1';
}
