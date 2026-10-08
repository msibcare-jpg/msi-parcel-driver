import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/order_status.dart';
import '../models/delivery_job.dart';
import '../models/driver_profile.dart';
import '../ui/kit.dart';
import 'backend.dart';

class FirebaseBackend implements Backend {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

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
      verificationFailed: (FirebaseAuthException e) {
        onError(_authMessage(e));
      },
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
      final cred = PhoneAuthProvider.credential(
        verificationId: id,
        smsCode: smsCode.trim(),
      );
      await _auth.signInWithCredential(cred);
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
  Future<void> signOut() async {
    try {
      await setOnline(false);
    } catch (_) {}
    await _auth.signOut();
  }

  // ---------------- Driver profile
  DocumentReference<Map<String, dynamic>> _driverDoc(String uid) =>
      _db.collection('drivers').doc(uid);

  @override
  Stream<DriverProfile?> watchDriver(String uid) {
    return _driverDoc(uid).snapshots().map((s) {
      final data = s.data();
      if (!s.exists || data == null) return null;
      return DriverProfile.fromMap(s.id, data);
    });
  }

  @override
  Future<List<String>> serviceCities() async {
    try {
      final q = await _db
          .collection('service_zones')
          .where('active', isEqualTo: true)
          .get();
      final names = q.docs
          .map((d) => (d.data()['name'] ?? d.id).toString())
          .where((n) => n.isNotEmpty)
          .toList()
        ..sort();
      if (names.isNotEmpty) return names;
    } catch (_) {}
    return ['Jeddah'];
  }

  Future<String> _upload(String uid, String name, File file) async {
    final ref = _storage.ref('drivers/$uid/$name.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  @override
  Future<void> submitRegistration(
    DriverRegistration reg, {
    required File licensePhoto,
    required File vehiclePhoto,
    required File selfie,
  }) async {
    final uid = _uid;
    final phone = _auth.currentUser?.phoneNumber ?? '';
    try {
      final licenseUrl = await _upload(uid, 'license', licensePhoto);
      final vehicleUrl = await _upload(uid, 'vehicle', vehiclePhoto);
      final selfieUrl = await _upload(uid, 'selfie', selfie);

      final batch = _db.batch();
      batch.set(
        _db.collection('users').doc(uid),
        {
          'role': 'driver',
          'phone': phone,
          'name': reg.name,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      batch.set(_driverDoc(uid), {
        'name': reg.name,
        'phone': phone,
        'idNumber': reg.idNumber,
        'city': reg.city,
        'vehicleType': reg.vehicleType,
        'plateNumber': reg.plateNumber,
        'status': DriverStatus.pending,
        'online': false,
        'documents': {
          'license': licenseUrl,
          'vehicle': vehicleUrl,
          'selfie': selfieUrl,
        },
        'submittedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } on FirebaseException catch (e) {
      throw BackendException(
          'Could not send your application (${e.code}). Try again.');
    }
  }

  @override
  Future<void> setOnline(bool online) async {
    await _driverDoc(_uid).update({
      'online': online,
      'lastSeenAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------- Deliveries
  @override
  Stream<List<DeliveryJob>> watchMyJobs(String uid) {
    return _db
        .collection('orders')
        .where('driverId', isEqualTo: uid)
        .snapshots()
        .map((s) {
      final jobs =
          s.docs.map((d) => DeliveryJob.fromMap(d.id, d.data())).toList();
      jobs.sort((a, b) {
        final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });
      return jobs;
    });
  }

  @override
  Future<void> advanceStatus(DeliveryJob job, String next) async {
    if (next == OrderStatus.delivered ||
        !OrderStatus.canMove(job.status, next)) {
      throw BackendException('This step is not allowed now.');
    }
    final uid = _uid;
    final ref = _db.collection('orders').doc(job.id);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data();
        if (!snap.exists || data == null) {
          throw BackendException('Order not found.');
        }
        if (data['driverId'] != uid) {
          throw BackendException('This order is no longer assigned to you.');
        }
        final current = (data['status'] ?? '').toString();
        if (!OrderStatus.canMove(current, next)) {
          throw BackendException(
              'Order is already "${OrderStatus.label(current)}".');
        }
        tx.update(ref, {
          'status': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(_db.collection('order_events').doc(), {
          'orderId': job.id,
          'status': next,
          'actorId': uid,
          'actorRole': 'driver',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      throw BackendException('Could not update the order (${e.code}).');
    }
  }

  @override
  Future<void> completeDelivery(
    DeliveryJob job, {
    required String otp,
    required bool codCollected,
  }) async {
    try {
      await _functions.httpsCallable('completeDelivery').call(<String, dynamic>{
        'orderId': job.id,
        'otp': otp.trim(),
        'codCollected': codCollected,
      });
    } on FirebaseFunctionsException catch (e) {
      throw BackendException(e.message ?? 'Could not complete the delivery.');
    }
  }

  // ---------------- Wallet
  @override
  Stream<List<WalletTx>> watchWallet(String uid) {
    return _db
        .collection('wallet_transactions')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((s) {
      final list = s.docs
          .map((d) => WalletTx.fromMap(d.id, d.data(), DeliveryJob.parseTime))
          .toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
      return list;
    });
  }

  // ---------------- Location
  @override
  Future<void> pushLocation({
    required double lat,
    required double lng,
    required double heading,
    required double speed,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _driverDoc(uid).update({
      'location': GeoPoint(lat, lng),
      'heading': heading,
      'speedMps': speed,
      'lastLocationAt': FieldValue.serverTimestamp(),
    });
  }
}
