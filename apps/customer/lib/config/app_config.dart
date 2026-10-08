/// App-wide switches.
///
/// [useFirebase] stays false until the Firebase project exists and
/// `lib/firebase_options.dart` is generated (`flutterfire configure`).
/// While false the app runs in DEMO mode with sample data on the phone.
class AppConfig {
  static const bool useFirebase =
      bool.fromEnvironment('USE_FIREBASE', defaultValue: false);

  static const String appName = 'MSI Parcel';
  static const String tagline = 'Fast. Reliable. Nearer to You.';
  static const String defaultCountryCode = '+966';
  static const String supportPhone = '+966 50 000 0000';
}
