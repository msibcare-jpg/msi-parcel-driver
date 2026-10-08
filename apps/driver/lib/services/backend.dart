import 'dart:io';

import '../models/delivery_job.dart';
import '../models/driver_profile.dart';
import '../ui/kit.dart';

class AuthUser {
  final String uid;
  final String phone;
  const AuthUser(this.uid, this.phone);
}

/// A message that can be shown to the driver as-is.
class BackendException implements Exception {
  final String message;
  BackendException(this.message);
  @override
  String toString() => message;
}

/// Everything the driver app needs from the server.
/// [FirebaseBackend] talks to Firebase; [DemoBackend] keeps sample data
/// on the phone so the app can be tried before Firebase is set up.
abstract class Backend {
  static late Backend instance;

  bool get isDemo;

  // ---- Sign in with phone number + SMS code
  Stream<AuthUser?> authChanges();
  AuthUser? get currentUser;
  Future<void> sendOtp(
    String phoneE164, {
    required void Function() onCodeSent,
    required void Function(String message) onError,
    void Function()? onAutoVerified,
  });
  Future<void> confirmOtp(String smsCode);
  Future<void> signOut();

  // ---- Driver profile & registration
  Stream<DriverProfile?> watchDriver(String uid);
  Future<List<String>> serviceCities();
  Future<void> submitRegistration(
    DriverRegistration reg, {
    required File licensePhoto,
    required File vehiclePhoto,
    required File selfie,
  });
  Future<void> setOnline(bool online);

  // ---- Deliveries
  /// All of this driver's orders (active and finished), newest first.
  Stream<List<DeliveryJob>> watchMyJobs(String uid);
  Future<void> advanceStatus(DeliveryJob job, String next);
  Future<void> completeDelivery(
    DeliveryJob job, {
    required String otp,
    required bool codCollected,
  });

  // ---- Wallet
  /// Money movements for this driver, newest first.
  Stream<List<WalletTx>> watchWallet(String uid);

  // ---- Live location
  Future<void> pushLocation({
    required double lat,
    required double lng,
    required double heading,
    required double speed,
  });
}
