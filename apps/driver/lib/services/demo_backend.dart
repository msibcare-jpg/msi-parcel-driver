import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../core/order_status.dart';
import '../models/delivery_job.dart';
import '../models/driver_profile.dart';
import '../ui/kit.dart';
import 'backend.dart';

/// Works fully on the phone with sample data. Used until Firebase is set up.
/// SMS code is always 123456. Delivery codes are shown in the job notes.
class DemoBackend implements Backend {
  static const demoSmsCode = '123456';

  final _changes = StreamController<void>.broadcast();
  AuthUser? _user;
  String _pendingPhone = '';
  DriverProfile? _driver;
  final List<DeliveryJob> _jobs = [];
  final Map<String, String> _otps = {};
  final List<WalletTx> _wallet = [];
  static const driverShare = 0.8;

  void _notify() => _changes.add(null);

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  @override
  bool get isDemo => true;

  @override
  Stream<AuthUser?> authChanges() => _watch(() => _user);

  @override
  AuthUser? get currentUser => _user;

  @override
  Future<void> sendOtp(
    String phoneE164, {
    required void Function() onCodeSent,
    required void Function(String message) onError,
    void Function()? onAutoVerified,
  }) async {
    _pendingPhone = phoneE164;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    onCodeSent();
  }

  @override
  Future<void> confirmOtp(String smsCode) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (smsCode.trim() != demoSmsCode) {
      throw BackendException('Wrong code. In demo mode the code is $demoSmsCode.');
    }
    _user = AuthUser('demo-driver', _pendingPhone);
    _notify();
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _driver = null;
    _jobs.clear();
    _wallet.clear();
    _notify();
  }

  @override
  Stream<DriverProfile?> watchDriver(String uid) => _watch(() => _driver);

  @override
  Future<List<String>> serviceCities() async => ['Jeddah', 'Makkah', 'Riyadh'];

  @override
  Future<void> submitRegistration(
    DriverRegistration reg, {
    required File licensePhoto,
    required File vehiclePhoto,
    required File selfie,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    _driver = DriverProfile(
      uid: _user?.uid ?? 'demo-driver',
      name: reg.name,
      phone: _user?.phone ?? '',
      city: reg.city,
      vehicleType: reg.vehicleType,
      plateNumber: reg.plateNumber,
      idNumber: reg.idNumber,
      status: DriverStatus.pending,
    );
    _notify();
  }

  /// Demo only: acts like the office approving the driver.
  Future<void> demoApprove() async {
    final d = _driver;
    if (d == null) return;
    _driver = d.copyWith(status: DriverStatus.approved);
    _seedJobs(d.city);
    _notify();
  }

  void _seedJobs(String city) {
    if (_jobs.isNotEmpty) return;
    final now = DateTime.now();
    _otps['demo-1'] = '4821';
    _otps['demo-2'] = '7305';
    _jobs.addAll([
      DeliveryJob(
        id: 'demo-1',
        code: 'MSI-100126',
        status: OrderStatus.assigned,
        city: city,
        pickupAddress: 'Al Safa, $city',
        dropoffAddress: 'Al Hamra, $city',
        senderName: 'Sample Sender',
        senderPhone: '+966500000001',
        receiverName: 'Sample Receiver',
        receiverPhone: '+966500000002',
        parcelType: 'Small box',
        notes: 'Demo delivery code: 4821',
        weightKg: 2,
        codAmount: 75,
        deliveryFee: 21,
        createdAt: now.subtract(const Duration(minutes: 20)),
      ),
      DeliveryJob(
        id: 'demo-2',
        code: 'MSI-100127',
        status: OrderStatus.assigned,
        city: city,
        pickupAddress: 'Al Rawdah, $city',
        dropoffAddress: 'Al Salamah, $city',
        senderName: 'Sample Shop',
        senderPhone: '+966500000003',
        receiverName: 'Sample Customer',
        receiverPhone: '+966500000004',
        parcelType: 'Documents',
        notes: 'Prepaid. Demo delivery code: 7305',
        weightKg: 0.5,
        codAmount: 0,
        deliveryFee: 20,
        createdAt: now.subtract(const Duration(minutes: 5)),
      ),
    ]);
    _seedHistory(city);
  }

  /// 30 days of sample finished deliveries so the dashboards have data.
  void _seedHistory(String city) {
    final rnd = Random(7);
    final today = DateTime.now();
    const areas = ['Al Rawdah', 'Al Safa', 'Al Hamra', 'Al Salamah', 'Al Naeem', 'Obhur', 'Al Zahra', 'Al Marwah'];
    var n = 200;
    for (var d = 30; d >= 0; d--) {
      final count = d == 0 ? 2 : rnd.nextInt(6) + 1;
      double codToday = 0;
      for (var k = 0; k < count; k++) {
        n++;
        final day = DateTime(today.year, today.month, today.day, 9 + rnd.nextInt(11), rnd.nextInt(60))
            .subtract(Duration(days: d));
        if (day.isAfter(today)) continue;
        final fee = 18.0 + rnd.nextInt(10);
        final cod = rnd.nextInt(3) == 0 ? 0.0 : (40 + rnd.nextInt(30) * 5).toDouble();
        final earn = double.parse((fee * driverShare).toStringAsFixed(2));
        final settled = d > 1;
        final code = 'MSI-10$n';
        _jobs.add(DeliveryJob(
          id: 'hist-$n',
          code: code,
          status: OrderStatus.delivered,
          city: city,
          pickupAddress: '${areas[rnd.nextInt(areas.length)]}, $city',
          dropoffAddress: '${areas[rnd.nextInt(areas.length)]}, $city',
          receiverName: 'Sample receiver',
          receiverPhone: '+9665000${n.toString().padLeft(5, '0')}',
          parcelType: 'Small box',
          weightKg: 1,
          codAmount: cod,
          deliveryFee: fee,
          driverEarning: earn,
          codCollected: cod > 0,
          codSettled: settled,
          createdAt: day.subtract(const Duration(minutes: 40)),
          deliveredAt: day,
        ));
        _wallet.add(WalletTx(id: 'e$n', type: 'earning', amount: earn, orderCode: code, createdAt: day));
        if (cod > 0) {
          _wallet.add(WalletTx(id: 'c$n', type: 'cod_collected', amount: -cod, orderCode: code, createdAt: day));
          if (settled) codToday += cod;
        }
      }
      if (codToday > 0) {
        final at = DateTime(today.year, today.month, today.day, 21).subtract(Duration(days: d));
        _wallet.add(WalletTx(id: 's$d', type: 'cod_settled', amount: codToday, createdAt: at));
      }
      if (d % 7 == 3) {
        final at = DateTime(today.year, today.month, today.day, 22).subtract(Duration(days: d));
        final paid = _wallet.where((t) => t.createdAt != null && t.createdAt!.isBefore(at)).fold<double>(0, (s, t) => s + t.amount);
        if (paid > 0) {
          _wallet.add(WalletTx(id: 'p$d', type: 'payout', amount: -double.parse(paid.toStringAsFixed(2)), note: 'Bank transfer', createdAt: at));
        }
      }
    }
  }

  @override
  Stream<List<WalletTx>> watchWallet(String uid) => _watch(() {
        final list = List<WalletTx>.from(_wallet);
        list.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
        return List<WalletTx>.unmodifiable(list);
      });

  @override
  Future<void> setOnline(bool online) async {
    final d = _driver;
    if (d == null) return;
    _driver = d.copyWith(online: online);
    _notify();
  }

  @override
  Stream<List<DeliveryJob>> watchMyJobs(String uid) =>
      _watch(() => List<DeliveryJob>.unmodifiable(_jobs));

  int _indexOf(String id) => _jobs.indexWhere((j) => j.id == id);

  @override
  Future<void> advanceStatus(DeliveryJob job, String next) async {
    final i = _indexOf(job.id);
    if (i < 0) throw BackendException('Order not found.');
    final current = _jobs[i];
    if (next == OrderStatus.delivered ||
        !OrderStatus.canMove(current.status, next)) {
      throw BackendException('This step is not allowed now.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _jobs[i] = current.copyWith(status: next);
    _notify();
  }

  @override
  Future<void> completeDelivery(
    DeliveryJob job, {
    required String otp,
    required bool codCollected,
  }) async {
    final i = _indexOf(job.id);
    if (i < 0) throw BackendException('Order not found.');
    final current = _jobs[i];
    if (current.status != OrderStatus.outForDelivery) {
      throw BackendException('Start the delivery first.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (_otps[job.id] != otp.trim()) {
      throw BackendException('Wrong delivery code. Ask the receiver again.');
    }
    if (current.hasCod && !codCollected) {
      throw BackendException('Confirm that you collected the cash.');
    }
    final now = DateTime.now();
    final earn = double.parse((current.deliveryFee * driverShare).toStringAsFixed(2));
    _jobs[i] = current.copyWith(
      status: OrderStatus.delivered,
      codCollected: current.hasCod,
      deliveredAt: now,
      driverEarning: earn,
    );
    _wallet.add(WalletTx(id: 'e-${current.id}', type: 'earning', amount: earn, orderCode: current.code, createdAt: now));
    if (current.hasCod) {
      _wallet.add(WalletTx(
          id: 'c-${current.id}', type: 'cod_collected', amount: -current.codAmount, orderCode: current.code, createdAt: now));
    }
    _notify();
  }

  @override
  Future<void> pushLocation({
    required double lat,
    required double lng,
    required double heading,
    required double speed,
  }) async {}
}
