/// Runtime configuration for HealthMate's public-data proxy.
///
/// Personal profiles, vaccination records and reports never leave the device.
/// Only public requests (news, campaigns, geocoding and nearby facilities) go
/// through this proxy. No private API keys belong in the Flutter bundle.
class AppConfig {
  AppConfig._();

  /// Base URL of the HealthMate public-data proxy
  /// (tools/healthmate_server.js). In release builds this must be HTTPS.
  static const String proxyBaseUrl = String.fromEnvironment(
    'HEALTHMATE_PROXY_URL',
    defaultValue: 'http://localhost:8787',
  );
}
