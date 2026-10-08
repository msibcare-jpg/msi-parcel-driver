import '../core/order_status.dart';

DateTime? parseTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  try {
    final d = (v as dynamic).toDate();
    if (d is DateTime) return d;
  } catch (_) {}
  return null;
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}') ?? 0;
}

double? _optNum(dynamic v) => v is num ? v.toDouble() : null;

class CustomerProfile {
  final String uid;
  final String name;
  final String phone;
  const CustomerProfile({required this.uid, required this.name, required this.phone});
}

class ServiceZone {
  final String name;
  final double baseFee;
  const ServiceZone(this.name, this.baseFee);
}

class Pricing {
  final double freeKg;
  final double perKgFee;
  final double codFeePct;
  const Pricing({this.freeKg = 5, this.perKgFee = 2, this.codFeePct = 1});

  factory Pricing.fromMap(Map<String, dynamic> m) => Pricing(
        freeKg: m['freeKg'] == null ? 5 : _num(m['freeKg']),
        perKgFee: m['perKgFee'] == null ? 2 : _num(m['perKgFee']),
        codFeePct: m['codFeePct'] == null ? 1 : _num(m['codFeePct']),
      );

  /// Delivery fee = city base fee + extra weight + COD handling.
  double quote(ServiceZone zone, double kg, double cod) {
    final extraKg = kg - freeKg;
    final fee = zone.baseFee + (extraKg > 0 ? extraKg * perKgFee : 0) + cod * codFeePct / 100;
    return (fee * 100).roundToDouble() / 100;
  }
}

class ParcelTypes {
  static const all = <String>['Documents', 'Small box', 'Medium box', 'Large box', 'Food', 'Electronics'];
}

class NewOrder {
  final String city;
  final String pickupAddress;
  final String dropoffAddress;
  final String senderName;
  final String senderPhone;
  final String receiverName;
  final String receiverPhone;
  final String parcelType;
  final double weightKg;
  final double codAmount;
  final double deliveryFee;
  final String notes;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;

  const NewOrder({
    required this.city,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.senderName,
    required this.senderPhone,
    required this.receiverName,
    required this.receiverPhone,
    required this.parcelType,
    required this.weightKg,
    required this.codAmount,
    required this.deliveryFee,
    required this.notes,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
  });
}

class ParcelOrder {
  final String id;
  final String code;
  final String status;
  final String city;
  final String pickupAddress;
  final String dropoffAddress;
  final String senderName;
  final String senderPhone;
  final String receiverName;
  final String receiverPhone;
  final String parcelType;
  final double weightKg;
  final double codAmount;
  final double deliveryFee;
  final String notes;
  final String driverName;
  final String driverPhone;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;

  const ParcelOrder({
    required this.id,
    required this.code,
    required this.status,
    required this.city,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.senderName = '',
    this.senderPhone = '',
    required this.receiverName,
    required this.receiverPhone,
    this.parcelType = '',
    this.weightKg = 0,
    this.codAmount = 0,
    this.deliveryFee = 0,
    this.notes = '',
    this.driverName = '',
    this.driverPhone = '',
    this.createdAt,
    this.deliveredAt,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
  });

  bool get hasCod => codAmount > 0;
  bool get isActive => status != OrderStatus.delivered && status != OrderStatus.cancelled;

  factory ParcelOrder.fromMap(String id, Map<String, dynamic> m) {
    String s(String k) => (m[k] ?? '').toString();
    return ParcelOrder(
      id: id,
      code: m['code'] == null ? id : s('code'),
      status: s('status'),
      city: s('city'),
      pickupAddress: s('pickupAddress'),
      dropoffAddress: s('dropoffAddress'),
      senderName: s('senderName'),
      senderPhone: s('senderPhone'),
      receiverName: s('receiverName'),
      receiverPhone: s('receiverPhone'),
      parcelType: s('parcelType'),
      weightKg: _num(m['weightKg']),
      codAmount: _num(m['codAmount']),
      deliveryFee: _num(m['deliveryFee']),
      notes: s('notes'),
      driverName: s('driverName'),
      driverPhone: s('driverPhone'),
      createdAt: parseTime(m['createdAt']),
      deliveredAt: parseTime(m['deliveredAt']),
      pickupLat: _optNum(m['pickupLat']),
      pickupLng: _optNum(m['pickupLng']),
      dropoffLat: _optNum(m['dropoffLat']),
      dropoffLng: _optNum(m['dropoffLng']),
    );
  }

  ParcelOrder copyWith({String? status, String? driverName, String? driverPhone, DateTime? deliveredAt}) {
    return ParcelOrder(
      id: id,
      code: code,
      status: status ?? this.status,
      city: city,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      senderName: senderName,
      senderPhone: senderPhone,
      receiverName: receiverName,
      receiverPhone: receiverPhone,
      parcelType: parcelType,
      weightKg: weightKg,
      codAmount: codAmount,
      deliveryFee: deliveryFee,
      notes: notes,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      createdAt: createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
    );
  }
}
