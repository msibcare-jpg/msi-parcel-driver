import 'package:flutter/material.dart';

import '../core/order_status.dart';
import '../ui/kit.dart';

class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case OrderStatus.delivered:
        return Pill(OrderStatus.label(status), fg: AppColors.ok, bg: AppColors.okSoft);
      case OrderStatus.cancelled:
        return Pill(OrderStatus.label(status), fg: AppColors.bad, bg: AppColors.badSoft);
      case OrderStatus.pickedUp:
      case OrderStatus.outForDelivery:
        return Pill(OrderStatus.label(status), fg: AppColors.teal, bg: AppColors.tealSoft);
      default:
        return Pill(OrderStatus.label(status), fg: AppColors.purple, bg: AppColors.purpleSoft);
    }
  }
}

class OrderProgress extends StatelessWidget {
  final String status;
  const OrderProgress(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    return ProgressSteps(
      step: OrderStatus.step(status),
      failed: status == OrderStatus.cancelled,
    );
  }
}
