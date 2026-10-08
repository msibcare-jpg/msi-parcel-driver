class DriverStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const suspended = 'suspended';
}

class VehicleTypes {
  static const all = <String>['Motorbike', 'Car', 'Van'];
}

class DriverProfile {
  final String uid;
  final String name;
  final String phone;
  final String city;
  final String vehicleType;
  final String plateNumber;
  final String idNumber;
  final String status;
  final String? rejectReason;
  final bool online;

  const DriverProfile({
    required this.uid,
    required this.name,
    required this.phone,
    required this.city,
    required this.vehicleType,
    required this.plateNumber,
    required this.idNumber,
    required this.status,
    this.rejectReason,
    this.online = false,
  });

  bool get isApproved => status == DriverStatus.approved;

  factory DriverProfile.fromMap(String uid, Map<String, dynamic> m) {
    String s(String k) => (m[k] ?? '').toString();
    final reason = m['rejectReason'];
    return DriverProfile(
      uid: uid,
      name: s('name'),
      phone: s('phone'),
      city: s('city'),
      vehicleType: s('vehicleType'),
      plateNumber: s('plateNumber'),
      idNumber: s('idNumber'),
      status: m['status'] == null ? DriverStatus.pending : s('status'),
      rejectReason: reason == null ? null : reason.toString(),
      online: m['online'] == true,
    );
  }

  DriverProfile copyWith({String? status, bool? online, String? rejectReason}) {
    return DriverProfile(
      uid: uid,
      name: name,
      phone: phone,
      city: city,
      vehicleType: vehicleType,
      plateNumber: plateNumber,
      idNumber: idNumber,
      status: status ?? this.status,
      rejectReason: rejectReason ?? this.rejectReason,
      online: online ?? this.online,
    );
  }
}

/// What the driver fills in on the sign-up form.
class DriverRegistration {
  final String name;
  final String idNumber;
  final String city;
  final String vehicleType;
  final String plateNumber;

  const DriverRegistration({
    required this.name,
    required this.idNumber,
    required this.city,
    required this.vehicleType,
    required this.plateNumber,
  });
}
