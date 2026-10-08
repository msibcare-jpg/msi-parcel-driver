import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/order_status.dart';
import '../models/models.dart';
import '../services/backend.dart';
import '../ui/kit.dart';
import '../widgets/order_widgets.dart';

/// Live tracking of one order, with the secret delivery code.
class OrderScreen extends StatefulWidget {
  final ParcelOrder order;
  final bool justBooked;
  const OrderScreen({super.key, required this.order, this.justBooked = false});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  late ParcelOrder _o;
  StreamSubscription<List<ParcelOrder>>? _sub;
  late final Stream<String?> _code;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _o = widget.order;
    _code = Backend.instance.watchDeliveryCode(_o.id);
    final uid = Backend.instance.currentUser?.uid;
    if (uid != null) {
      _sub = Backend.instance.watchMyOrders(uid).listen((list) {
        for (final o in list) {
          if (o.id == _o.id && mounted) setState(() => _o = o);
        }
      }, onError: (_) {});
    }
    if (widget.justBooked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showMessage(context, 'Booked! We are finding a driver for ${_o.code}.');
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text('${_o.code} will be cancelled. No fee is charged.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel order')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await Backend.instance.cancelOrder(_o);
      if (mounted) showMessage(context, 'Order cancelled');
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _headline() {
    switch (_o.status) {
      case OrderStatus.pending:
        return 'Finding a driver';
      case OrderStatus.assigned:
        return 'Driver assigned';
      case OrderStatus.accepted:
        return 'Driver is on the way to pickup';
      case OrderStatus.pickedUp:
        return 'Parcel picked up';
      case OrderStatus.outForDelivery:
        return 'Out for delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      default:
        return OrderStatus.label(_o.status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _o;
    final done = o.status == OrderStatus.delivered;
    final cancelled = o.status == OrderStatus.cancelled;
    final steps = [
      ('Booked', OrderStatus.pending),
      ('Driver assigned', OrderStatus.assigned),
      ('Picked up', OrderStatus.pickedUp),
      ('Out for delivery', OrderStatus.outForDelivery),
      ('Delivered', OrderStatus.delivered),
    ];
    final current = OrderStatus.step(o.status);

    return Scaffold(
      appBar: AppBar(title: Text(o.code)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          HeroCard(
            gradient: cancelled
                ? const LinearGradient(colors: [Color(0xFF5A5368), Color(0xFF7A7388)])
                : done
                    ? tealGradient
                    : brandGradient,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(
                    done
                        ? Icons.verified_rounded
                        : cancelled
                            ? Icons.cancel_outlined
                            : Icons.local_shipping_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(o.city, style: const TextStyle(color: AppColors.white70)),
                  const Spacer(),
                  Text(shortTime(o.createdAt), style: const TextStyle(color: AppColors.white70, fontSize: 12.5)),
                ]),
                const SizedBox(height: 12),
                Text(_headline(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                Row(
                  children: List.generate(5, (i) {
                    final on = !cancelled && i < current;
                    return Expanded(
                      child: Container(
                        height: 6,
                        margin: EdgeInsets.only(right: i == 4 ? 0 : 5),
                        decoration: BoxDecoration(
                          color: on ? Colors.white : AppColors.white20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (!done && !cancelled)
            StreamBuilder<String?>(
              stream: _code,
              builder: (context, snap) {
                final code = snap.data;
                return Panel(
                  color: AppColors.purpleSoft,
                  borderColor: AppColors.purpleSoft,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Delivery code', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.purple)),
                            const SizedBox(height: 2),
                            Text('Share only with ${o.receiverName.isEmpty ? 'the receiver' : o.receiverName}. The driver needs it to finish.',
                                style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: code == null
                            ? null
                            : () async {
                                await Clipboard.setData(ClipboardData(text: code));
                                if (context.mounted) showMessage(context, 'Code copied');
                              },
                        child: Text(
                          code ?? '····',
                          style: const TextStyle(
                              fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 6, color: AppColors.purpleDeep),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          if (!done && !cancelled) const SizedBox(height: 12),
          if (o.driverName.isNotEmpty)
            Panel(
              child: Row(children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.tealSoft,
                  child: Icon(Icons.delivery_dining_rounded, color: AppColors.teal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(o.driverName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const Text('Your MSI driver', style: TextStyle(color: AppColors.muted)),
                  ]),
                ),
                if (o.driverPhone.isNotEmpty && !done && !cancelled)
                  IconButton.filled(
                    onPressed: () => callNumber(context, o.driverPhone),
                    icon: const Icon(Icons.call),
                  ),
              ]),
            ),
          if (o.driverName.isNotEmpty) const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Progress', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 10),
                ...List.generate(steps.length, (i) {
                  final reached = !cancelled && OrderStatus.step(steps[i].$2) <= current;
                  final isNow = !cancelled && OrderStatus.step(steps[i].$2) == current;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: reached ? tealGradient : null,
                          color: reached ? null : AppColors.line,
                        ),
                        child: Icon(reached ? Icons.check_rounded : Icons.circle, size: reached ? 16 : 8, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(steps[i].$1,
                            style: TextStyle(
                              fontWeight: isNow ? FontWeight.w800 : FontWeight.w500,
                              color: reached ? AppColors.ink : AppColors.muted,
                            )),
                      ),
                      if (i == 0) Text(shortTime(o.createdAt), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      if (i == 4 && done)
                        Text(shortTime(o.deliveredAt), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ]),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RouteLines(from: o.pickupAddress, to: o.dropoffAddress),
                const Divider(height: 28),
                InfoRow('Receiver', '${o.receiverName} · ${o.receiverPhone}'),
                InfoRow('Parcel', '${o.parcelType} · ${o.weightKg.toStringAsFixed(1)} kg'),
                if (o.notes.isNotEmpty) InfoRow('Note', o.notes),
                const Divider(height: 24),
                InfoRow('Delivery fee', money(o.deliveryFee), bold: true),
                InfoRow('Cash to collect', o.hasCod ? money(o.codAmount) : 'None (prepaid)', bold: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            StatusPill(o.status),
            const Spacer(),
            if (o.status == OrderStatus.pending)
              TextButton.icon(
                onPressed: _busy ? null : _cancel,
                icon: const Icon(Icons.close_rounded, color: AppColors.bad),
                label: const Text('Cancel order', style: TextStyle(color: AppColors.bad)),
              ),
          ]),
        ],
      ),
    );
  }
}
