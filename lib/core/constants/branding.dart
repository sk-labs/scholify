class AppBranding {
  static const String appName = 'Scholify';
  static const String productTagline =
      'Desktop-first multi-tenant school platform';

  // Replace with your production PocketBase URL for Scholify.
  // Overridable at build time: --dart-define=POCKETBASE_URL=http://localhost:8090
  static const String defaultPocketBaseUrl = String.fromEnvironment(
    'POCKETBASE_URL',
    defaultValue: 'https://vm-hms.lixcure.com',
  );
}
