import 'dart:async';
import 'dart:math';

import '../core/order_status.dart';
import '../models/models.dart';
import '../ui/kit.dart';
import 'backend.dart';

/// Works fully on the phone with sample data. Used until Firebase is set up.
/// SMS code is always 123456. New orders move forward by themselves
/// every few seconds so live tracking can be tried.
class DemoBackend implements Backend {
  static const demoSmsCode = '123456';

  final _changes = StreamController<void>.broadcast();
  final _rnd = Random();
  AuthUser? _user;
  String _pendingPhone = '';
  CustomerProfile? _profile;
  final List<ParcelOrder> _orders = [];
  final Map<String, String> _codes = {};
  final List<WalletTx> _wallet = [];

  void _notify() => _changes.add(null);

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  @override
  bool get isDemo => true;

  // ---------------- Auth
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
    _user = AuthUser('demo-customer', _pendingPhone);
    _notify();
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _profile = null;
    _orders.clear();
    _wallet.clear();
    _notify();
  }

  // ---------------- Profile
  @override
  Stream<CustomerProfile?> watchProfile(String uid) => _watch(() => _profile);

  @override
  Future<void> saveProfile(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _profile = CustomerProfile(uid: _user?.uid ?? 'demo-customer', name: name, phone: _user?.phone ?? '');
    if (_orders.isEmpty) _seedHistory();
    _notify();
  }

  // ---------------- Prices
  @override
  Future<List<ServiceZone>> serviceZones() async =>
      const [ServiceZone('Jeddah', 20), ServiceZone('Makkah', 22), ServiceZone('Riyadh', 25)];

  @override
  Future<Pricing> pricing() async => const Pricing();

  // ---------------- Orders
  String _newCode() => 'MSI-${100000 + _rnd.nextInt(899999)}';

  @override
  Future<ParcelOrder> createOrder(NewOrder o) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final id = 'o${DateTime.now().millisecondsSinceEpoch}';
    final order = ParcelOrder(
      id: id,
      code: _newCode(),
      status: OrderStatus.pending,
      city: o.city,
      pickupAddress: o.pickupAddress,
      dropoffAddress: o.dropoffAddress,
      senderName: o.senderName,
      senderPhone: o.senderPhone,
      receiverName: o.receiverName,
      receiverPhone: o.receiverPhone,
      parcelType: o.parcelType,
      weightKg: o.weightKg,
      codAmount: o.codAmount,
      deliveryFee: o.deliveryFee,
      notes: o.notes,
      createdAt: DateTime.now(),
    );
    _orders.add(order);
    _codes[id] = (1000 + _rnd.nextInt(9000)).toString();
    _notify();
    _simulate(id);
    return order;
  }

  /// Moves a new demo order through the delivery steps.
  void _simulate(String id) {
    const steps = [
      OrderStatus.assigned,
      OrderStatus.accepted,
      OrderStatus.pickedUp,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
    ];
    var i = 0;
    Timer.periodic(const Duration(seconds: 8), (t) {
      final idx = _orders.indexWhere((o) => o.id == id);
      if (idx < 0 || !_orders[idx].isActive || i >= steps.length) {
        t.cancel();
        return;
      }
      final next = steps[i++];
      final cur = _orders[idx];
      _orders[idx] = cur.copyWith(
        status: next,
        driverName: 'Test Driver',
        driverPhone: '+966500000009',
        deliveredAt: next == OrderStatus.delivered ? DateTime.now() : null,
      );
      if (next == OrderStatus.delivered) _settle(_orders[idx]);
      _notify();
    });
  }

  void _settle(ParcelOrder o) {
    final at = o.deliveredAt ?? DateTime.now();
    if (o.hasCod) {
      _wallet.add(WalletTx(id: 'r-${o.id}', type: 'cod_received', amount: o.codAmount, orderCode: o.code, createdAt: at));
    }
    _wallet.add(WalletTx(id: 'f-${o.id}', type: 'delivery_fee', amount: -o.deliveryFee, orderCode: o.code, createdAt: at));
  }

  void _seedHistory() {
    final rnd = Random(11);
    final now = DateTime.now();
    const areas = ['Al Rawdah', 'Al Safa', 'Al Hamra', 'Al Salamah', 'Al Naeem', 'Obhur', 'Al Zahra', 'Al Marwah'];
    const names = ['Ahmed', 'Fatima', 'Omar', 'Sara', 'Khalid', 'Noura', 'Yusuf', 'Aisha'];
    var n = 500;
    for (var d = 30; d >= 1; d--) {
      final count = rnd.nextInt(4);
      for (var k = 0; k < count; k++) {
        n++;
        final at = DateTime(now.year, now.month, now.day, 10 + rnd.nextInt(10), rnd.nextInt(60)).subtract(Duration(days: d));
        final cod = rnd.nextInt(3) == 0 ? 0.0 : (50 + rnd.nextInt(40) * 5).toDouble();
        final fee = 20.0 + rnd.nextInt(8);
        final cancelled = rnd.nextInt(14) == 0;
        final o = ParcelOrder(
          id: 'h$n',
          code: 'MSI-$n${rnd.nextInt(90) + 10}',
          status: cancelled ? OrderStatus.cancelled : OrderStatus.delivered,
          city: 'Jeddah',
          pickupAddress: '${areas[rnd.nextInt(areas.length)]}, Jeddah',
          dropoffAddress: '${areas[rnd.nextInt(areas.length)]}, Jeddah',
          receiverName: names[rnd.nextInt(names.length)],
          receiverPhone: '+9665000${n.toString().padLeft(5, '0')}',
          parcelType: ParcelTypes.all[rnd.nextInt(4)],
          weightKg: 1.0 + rnd.nextInt(4),
          codAmount: cod,
          deliveryFee: fee,
          driverName: 'Test Driver',
          createdAt: at.subtract(const Duration(hours: 2)),
          deliveredAt: cancelled ? null : at,
        );
        _orders.add(o);
        if (!cancelled) _settle(o);
      }
      if (d == 15 || d == 4) {
        final bal = walletBalance(_wallet);
        if (bal > 100) {
          final at = DateTime(now.year, now.month, now.day, 20).subtract(Duration(days: d));
          _wallet.add(WalletTx(id: 'w$d', type: 'withdrawal', amount: -(bal - 50).roundToDouble(), note: 'Bank transfer', createdAt: at));
        }
      }
    }
  }

  @override
  Stream<List<ParcelOrder>> watchMyOrders(String uid) => _watch(() {
        final list = List<ParcelOrder>.from(_orders);
        list.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
        return List<ParcelOrder>.unmodifiable(list);
      });

  @override
  Stream<String?> watchDeliveryCode(String orderId) => _watch(() => _codes[orderId]);

  @override
  Future<void> cancelOrder(ParcelOrder order) async {
    final i = _orders.indexWhere((o) => o.id == order.id);
    if (i < 0) throw BackendException('Order not found.');
    if (_orders[i].status != OrderStatus.pending) {
      throw BackendException('A driver is already on the way. Call the office to cancel.');
    }
    _orders[i] = _orders[i].copyWith(status: OrderStatus.cancelled);
    _notify();
  }

  // ---------------- Wallet
  @override
  Stream<List<WalletTx>> watchWallet(String uid) => _watch(() {
        final list = List<WalletTx>.from(_wallet);
        list.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
        return List<WalletTx>.unmodifiable(list);
      });

  @override
  Future<void> requestWithdrawal(double amount) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final bal = walletBalance(_wallet);
    if (amount <= 0 || amount > bal) throw BackendException('Enter an amount up to ${money(bal)}.');
    _wallet.add(WalletTx(
      id: 'w${DateTime.now().millisecondsSinceEpoch}',
      type: 'withdrawal',
      amount: -amount,
      note: 'Requested',
      createdAt: DateTime.now(),
    ));
    _notify();
  }
}
