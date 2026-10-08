/// App-wide switches.
///
/// [useFirebase] is false until the Firebase project exists and
/// `lib/firebase_options.dart` has been generated with `flutterfire configure`.
/// While false, the app runs in DEMO mode: everything works on the phone
/// with sample data, nothing is sent to a server.
///
/// The build can also turn it on with: --dart-define=USE_FIREBASE=true
class AppConfig {
  static const bool useFirebase =
      bool.fromEnvironment('USE_FIREBASE', defaultValue: false);

  static const String appName = 'MSI Parcel Driver';
  static const String tagline = 'Fast. Reliable. Nearer to You.';
  static const String defaultCountryCode = '+966';
  static const String currency = 'SAR';
  static const String supportPhone = '+966 50 000 0000';
}
