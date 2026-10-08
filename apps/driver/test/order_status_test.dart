import 'package:flutter_test/flutter_test.dart';
import 'package:msi_parcel_driver/core/order_status.dart';
import 'package:msi_parcel_driver/models/delivery_job.dart';

void main() {
  test('driver can only move forward one step at a time', () {
    expect(OrderStatus.canMove(OrderStatus.assigned, OrderStatus.accepted), isTrue);
    expect(OrderStatus.canMove(OrderStatus.assigned, OrderStatus.delivered), isFalse);
    expect(OrderStatus.canMove(OrderStatus.delivered, OrderStatus.assigned), isFalse);
    expect(OrderStatus.nextManual(OrderStatus.pickedUp), OrderStatus.outForDelivery);
    expect(OrderStatus.nextManual(OrderStatus.outForDelivery), isNull);
  });

  test('order data is read safely', () {
    final j = DeliveryJob.fromMap('o1', {
      'status': 'assigned',
      'pickupAddress': 'A',
      'dropoffAddress': 'B',
      'receiverName': 'R',
      'receiverPhone': '1',
      'codAmount': 75,
      'createdAt': 1700000000000,
    });
    expect(j.code, 'o1');
    expect(j.hasCod, isTrue);
    expect(j.createdAt, isNotNull);
  });
}
