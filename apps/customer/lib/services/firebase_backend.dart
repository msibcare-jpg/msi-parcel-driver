import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/order_status.dart';
import '../models/models.dart';
import '../ui/kit.dart';
import 'backend.dart';

class FirebaseBackend implements Backend {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _rnd = Random.secure();

  String? _verificationId;
  int? _resendToken;

  @override
  bool get isDemo => false;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw BackendException('Please sign in again.');
    return u.uid;
  }

  AuthUser? _map(User? u) => u == null ? null : AuthUser(u.uid, u.phoneNumber ?? '');

  // ---------------- Auth
  @override
  Stream<AuthUser?> authChanges() => _auth.authStateChanges().map(_map);

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<void> sendOtp(
    String phoneE164, {
    required void Function() onCodeSent,
    required void Function(String message) onError,
    void Function()? onAutoVerified,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await _auth.signInWithCredential(credential);
          if (onAutoVerified != null) onAutoVerified();
        } catch (e) {
          onError('Automatic sign in failed. Enter the code manually.');
        }
      },
      verificationFailed: (FirebaseAuthException e) => onError(_authMessage(e)),
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        onCodeSent();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  @override
  Future<void> confirmOtp(String smsCode) async {
    final id = _verificationId;
    if (id == null) throw BackendException('Request a new code first.');
    try {
      await _auth.signInWithCredential(
        PhoneAuthProvider.credential(verificationId: id, smsCode: smsCode.trim()),
      );
    } on FirebaseAuthException catch (e) {
      throw BackendException(_authMessage(e));
    }
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'This phone number is not valid.';
      case 'invalid-verification-code':
        return 'Wrong code. Check the SMS and try again.';
      case 'session-expired':
        return 'The code expired. Request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a while and try again.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return e.message ?? 'Sign in failed (${e.code}).';
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  // ---------------- Profile
  @override
  Stream<CustomerProfile?> watchProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((s) {
      final m = s.data();
      if (m == null) return null;
      final name = (m['name'] ?? '').toString();
      if (name.isEmpty) return null;
      return CustomerProfile(uid: uid, name: name, phone: (m['phone'] ?? '').toString());
    });
  }

  @override
  Future<void> saveProfile(String name) async {
    final uid = _uid;
    await _db.collection('users').doc(uid).set({
      'role': 'customer',
      'name': name,
      'phone': _auth.currentUser?.phoneNumber ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------- Prices
  @override
  Future<List<ServiceZone>> serviceZones() async {
    try {
      final q = await _db.collection('service_zones').where('active', isEqualTo: true).get();
      final zones = q.docs.map((d) {
        final m = d.data();
        final f = m['baseFee'];
        return ServiceZone((m['name'] ?? d.id).toString(), f is num ? f.toDouble() : 20);
      }).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      if (zones.isNotEmpty) return zones;
    } catch (_) {}
    return const [ServiceZone('Jeddah', 20)];
  }

  @override
  Future<Pricing> pricing() async {
    try {
      final d = await _db.collection('pricing_rules').doc('default').get();
      final m = d.data();
      if (m != null) return Pricing.fromMap(m);
    } catch (_) {}
    return const Pricing();
  }

  // ---------------- Orders
  @override
  Future<ParcelOrder> createOrder(NewOrder o) async {
    final uid = _uid;
    final ref = _db.collection('orders').doc();
    final code = 'MSI-${100000 + _rnd.nextInt(899999)}';
    final data = <String, dynamic>{
      'code': code,
      'customerId': uid,
      'status': OrderStatus.pending,
      'driverId': '',
      'city': o.city,
      'pickupAddress': o.pickupAddress,
      'dropoffAddress': o.dropoffAddress,
      'senderName': o.senderName,
      'senderPhone': o.senderPhone,
      'receiverName': o.receiverName,
      'receiverPhone': o.receiverPhone,
      'parcelType': o.parcelType,
      'weightKg': o.weightKg,
      'codAmount': o.codAmount,
      'deliveryFee': o.deliveryFee,
      'notes': o.notes,
      if (o.pickupLat != null) 'pickupLat': o.pickupLat,
      if (o.pickupLng != null) 'pickupLng': o.pickupLng,
      if (o.dropoffLat != null) 'dropoffLat': o.dropoffLat,
      if (o.dropoffLng != null) 'dropoffLng': o.dropoffLng,
      'createdAt': FieldValue.serverTimestamp(),
    };
    try {
      await ref.set(data);
    } on FirebaseException catch (e) {
      throw BackendException('Could not book the delivery (${e.code}).');
    }
    return ParcelOrder.fromMap(ref.id, {...data, 'createdAt': DateTime.now()});
  }

  @override
  Stream<List<ParcelOrder>> watchMyOrders(String uid) {
    return _db.collection('orders').where('customerId', isEqualTo: uid).snapshots().map((s) {
      final list = s.docs.map((d) => ParcelOrder.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return list;
    });
  }

  @override
  Stream<String?> watchDeliveryCode(String orderId) {
    return _db
        .collection('orders')
        .doc(orderId)
        .collection('private')
        .doc('otp')
        .snapshots()
        .map((s) => s.data()?['code']?.toString());
  }

  @override
  Future<void> cancelOrder(ParcelOrder order) async {
    try {
      await _db.collection('orders').doc(order.id).update({
        'status': OrderStatus.cancelled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      throw BackendException('A driver is already on the way. Call the office to cancel.');
    }
  }

  // ---------------- Wallet
  @override
  Stream<List<WalletTx>> watchWallet(String uid) {
    return _db.collection('wallet_transactions').where('uid', isEqualTo: uid).snapshots().map((s) {
      final list = s.docs.map((d) => WalletTx.fromMap(d.id, d.data(), parseTime)).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
      return list;
    });
  }

  @override
  Future<void> requestWithdrawal(double amount) async {
    if (amount <= 0) throw BackendException('Enter an amount.');
    await _db.collection('withdrawal_requests').add({
      'uid': _uid,
      'amount': amount,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
