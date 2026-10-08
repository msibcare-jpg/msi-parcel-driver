class DeliveryJob {
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
  final String notes;
  final double weightKg;
  final double codAmount;
  final double deliveryFee;
  final double driverEarning;
  final bool codCollected;
  final bool codSettled;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;

  const DeliveryJob({
    required this.id,
    required this.code,
    required this.status,
    this.city = '',
    required this.pickupAddress,
    required this.dropoffAddress,
    this.senderName = '',
    this.senderPhone = '',
    required this.receiverName,
    required this.receiverPhone,
    this.parcelType = '',
    this.notes = '',
    this.weightKg = 0,
    this.codAmount = 0,
    this.deliveryFee = 0,
    this.driverEarning = 0,
    this.codCollected = false,
    this.codSettled = false,
    this.createdAt,
    this.deliveredAt,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
  });

  bool get hasCod => codAmount > 0;

  /// Accepts Firestore Timestamps, DateTime or epoch milliseconds.
  static DateTime? parseTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    try {
      final d = (v as dynamic).toDate();
      if (d is DateTime) return d;
    } catch (_) {}
    return null;
  }

  static double? _opt(dynamic v) => v is num ? v.toDouble() : null;

  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}') ?? 0;
  }

  factory DeliveryJob.fromMap(String id, Map<String, dynamic> m) {
    String s(String k) => (m[k] ?? '').toString();
    return DeliveryJob(
      id: id,
      code: m['code'] == null ? id : s('code'),
      status: s('status'),
      city: s('city'),
      pickupAddress: s('pickupAddress'),
      dropoffAddress: s('dropoffAddress'),
      senderName: m['senderName'] != null ? s('senderName') : s('customerName'),
      senderPhone:
          m['senderPhone'] != null ? s('senderPhone') : s('customerPhone'),
      receiverName: s('receiverName'),
      receiverPhone: s('receiverPhone'),
      parcelType: s('parcelType'),
      notes: s('notes'),
      weightKg: _num(m['weightKg']),
      codAmount: _num(m['codAmount']),
      deliveryFee: _num(m['deliveryFee']),
      driverEarning: _num(m['driverEarning']),
      codCollected: m['codCollected'] == true,
      codSettled: m['codSettled'] == true,
      createdAt: parseTime(m['createdAt']),
      deliveredAt: parseTime(m['deliveredAt']),
      pickupLat: _opt(m['pickupLat']),
      pickupLng: _opt(m['pickupLng']),
      dropoffLat: _opt(m['dropoffLat']),
      dropoffLng: _opt(m['dropoffLng']),
    );
  }

  DeliveryJob copyWith({
    String? status,
    bool? codCollected,
    bool? codSettled,
    DateTime? deliveredAt,
    double? driverEarning,
  }) {
    return DeliveryJob(
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
      notes: notes,
      weightKg: weightKg,
      codAmount: codAmount,
      deliveryFee: deliveryFee,
      driverEarning: driverEarning ?? this.driverEarning,
      codCollected: codCollected ?? this.codCollected,
      codSettled: codSettled ?? this.codSettled,
      createdAt: createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
    );
  }
}
