import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/order_status.dart';
import '../models/delivery_job.dart';
import '../services/backend.dart';
import '../ui/kit.dart';
import '../widgets/order_widgets.dart';

/// One delivery: details, call / map buttons, the next status step,
/// and delivery-code (OTP) confirmation at the door.
class JobScreen extends StatefulWidget {
  final DeliveryJob job;
  const JobScreen({super.key, required this.job});

  @override
  State<JobScreen> createState() => _JobScreenState();
}

class _JobScreenState extends State<JobScreen> {
  late DeliveryJob _job;
  StreamSubscription<List<DeliveryJob>>? _sub;
  final _otp = TextEditingController();
  bool _cashCollected = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    final uid = Backend.instance.currentUser?.uid;
    if (uid != null) {
      // Keep this screen in sync if the office changes the order.
      _sub = Backend.instance.watchMyJobs(uid).listen((jobs) {
        DeliveryJob? found;
        for (final j in jobs) {
          if (j.id == _job.id) found = j;
        }
        if (!mounted) return;
        if (found == null) {
          showMessage(context, 'This delivery was reassigned by the office.', error: true);
          Navigator.of(context).maybePop();
          return;
        }
        setState(() => _job = found!);
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _advance() async {
    final next = OrderStatus.nextManual(_job.status);
    if (next == null) return;
    setState(() => _busy = true);
    try {
      await Backend.instance.advanceStatus(_job, next);
      if (!mounted) return;
      setState(() => _job = _job.copyWith(status: next));
      showMessage(context, OrderStatus.label(next));
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final code = _otp.text.trim();
    if (code.length != 4) {
      showMessage(context, 'Enter the 4-digit delivery code from the receiver.', error: true);
      return;
    }
    if (_job.hasCod && !_cashCollected) {
      showMessage(context, 'Collect ${money(_job.codAmount)} and tick the box first.', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await Backend.instance.completeDelivery(_job, otp: code, codCollected: _cashCollected);
      if (!mounted) return;
      _sub?.cancel();
      showMessage(context, '${_job.code} delivered. Well done!');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _contact(String role, String name, String phone, String address) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(role.toUpperCase(),
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w700, letterSpacing: .6)),
          const SizedBox(height: 6),
          Text(address, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
          if (name.isNotEmpty || phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text([name, phone].where((s) => s.isNotEmpty).join(' · '), style: const TextStyle(color: AppColors.muted)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (phone.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => callNumber(context, phone),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Call'),
                  ),
                ),
              if (phone.isNotEmpty) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openMap(context, address),
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  label: const Text('Map'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final j = _job;
    final next = OrderStatus.nextManual(j.status);
    final atDoor = j.status == OrderStatus.outForDelivery;
    final done = j.status == OrderStatus.delivered || j.status == OrderStatus.cancelled;
    // Before pickup the sender matters most; after pickup the receiver.
    final pickupFirst = j.status == OrderStatus.assigned || j.status == OrderStatus.accepted;
    final pickupCard = _contact('Pickup', j.senderName, j.senderPhone, j.pickupAddress);
    final dropCard = _contact('Drop-off', j.receiverName, j.receiverPhone, j.dropoffAddress);

    return Scaffold(
      appBar: AppBar(title: Text(j.code)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              StatusPill(j.status),
              const Spacer(),
              Text(shortTime(j.createdAt), style: const TextStyle(color: AppColors.muted)),
            ]),
            const SizedBox(height: 12),
            OrderProgress(j.status),
            const SizedBox(height: 16),
            Panel(
              color: j.hasCod ? AppColors.warnSoft : AppColors.okSoft,
              borderColor: j.hasCod ? AppColors.warnSoft : AppColors.okSoft,
              child: Row(
                children: [
                  Icon(j.hasCod ? Icons.payments : Icons.verified, color: j.hasCod ? AppColors.warn : AppColors.ok),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      j.hasCod ? 'Collect ${money(j.codAmount)} cash from the receiver' : 'Prepaid. Do not collect any cash.',
                      style: TextStyle(fontWeight: FontWeight.w700, color: j.hasCod ? AppColors.warn : AppColors.ok),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (pickupFirst) ...[pickupCard, const SizedBox(height: 12), dropCard] else ...[dropCard, const SizedBox(height: 12), pickupCard],
            const SizedBox(height: 12),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PARCEL', style: TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w700, letterSpacing: .6)),
                  const SizedBox(height: 6),
                  Text('${j.parcelType.isEmpty ? 'Parcel' : j.parcelType}${j.weightKg > 0 ? ' · ${j.weightKg.toStringAsFixed(1)} kg' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (j.notes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(j.notes, style: const TextStyle(color: AppColors.muted)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (next != null)
              FilledButton(
                onPressed: _busy ? null : _advance,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(OrderStatus.actionLabel(j.status)),
              ),
            if (atDoor)
              Panel(
                borderColor: AppColors.teal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Hand over the parcel',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('Ask the receiver for the 4-digit delivery code they got from MSI Parcel.',
                        style: TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _otp,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 28, letterSpacing: 14, fontWeight: FontWeight.w800),
                      decoration: const InputDecoration(counterText: '', hintText: '••••'),
                    ),
                    if (j.hasCod)
                      CheckboxListTile(
                        value: _cashCollected,
                        onChanged: _busy ? null : (v) => setState(() => _cashCollected = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text('I collected ${money(j.codAmount)} cash'),
                      ),
                    const SizedBox(height: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                      onPressed: _busy ? null : _complete,
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('Confirm delivery'),
                    ),
                  ],
                ),
              ),
            if (done)
              Panel(
                child: Text(
                  j.status == OrderStatus.delivered ? 'This delivery is complete.' : 'This order was cancelled.',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
