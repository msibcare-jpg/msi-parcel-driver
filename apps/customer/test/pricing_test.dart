import 'package:flutter_test/flutter_test.dart';
import 'package:msi_parcel_customer/models/models.dart';

void main() {
  test('delivery fee = base + extra weight + COD handling', () {
    const p = Pricing(freeKg: 5, perKgFee: 2, codFeePct: 1);
    const jeddah = ServiceZone('Jeddah', 20);
    expect(p.quote(jeddah, 1, 0), 20);
    expect(p.quote(jeddah, 7, 0), 24);
    expect(p.quote(jeddah, 7, 100), 25);
  });

  test('order data is read safely', () {
    final o = ParcelOrder.fromMap('x1', {
      'status': 'pending',
      'pickupAddress': 'A',
      'dropoffAddress': 'B',
      'receiverName': 'R',
      'receiverPhone': '1',
      'codAmount': 50,
      'createdAt': 1700000000000,
    });
    expect(o.code, 'x1');
    expect(o.hasCod, isTrue);
    expect(o.isActive, isTrue);
  });
}
