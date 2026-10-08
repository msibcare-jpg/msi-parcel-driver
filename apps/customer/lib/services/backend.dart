import '../models/models.dart';
import '../ui/kit.dart';

class AuthUser {
  final String uid;
  final String phone;
  const AuthUser(this.uid, this.phone);
}

/// A message that can be shown to the customer as-is.
class BackendException implements Exception {
  final String message;
  BackendException(this.message);
  @override
  String toString() => message;
}

/// Everything the customer app needs from the server.
abstract class Backend {
  static late Backend instance;

  bool get isDemo;

  // ---- Sign in
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

  // ---- Profile
  Stream<CustomerProfile?> watchProfile(String uid);
  Future<void> saveProfile(String name);

  // ---- Prices
  Future<List<ServiceZone>> serviceZones();
  Future<Pricing> pricing();

  // ---- Orders
  Future<ParcelOrder> createOrder(NewOrder order);
  Stream<List<ParcelOrder>> watchMyOrders(String uid);
  /// The secret 4-digit code the receiver gives the driver.
  Stream<String?> watchDeliveryCode(String orderId);
  Future<void> cancelOrder(ParcelOrder order);

  // ---- Wallet
  Stream<List<WalletTx>> watchWallet(String uid);
  Future<void> requestWithdrawal(double amount);
}
