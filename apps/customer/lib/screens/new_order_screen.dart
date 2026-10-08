import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/backend.dart';
import '../ui/kit.dart';
import 'order_screen.dart';

/// Book a delivery: pickup, drop-off, parcel, cash on delivery, price.
class NewOrderScreen extends StatefulWidget {
  final CustomerProfile profile;
  const NewOrderScreen({super.key, required this.profile});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _senderName;
  late final TextEditingController _senderPhone;
  final _pickup = TextEditingController();
  final _dropoff = TextEditingController();
  final _receiverName = TextEditingController();
  final _receiverPhone = TextEditingController();
  final _cod = TextEditingController();
  final _notes = TextEditingController();

  List<ServiceZone> _zones = const [];
  ServiceZone? _zone;
  Pricing _pricing = const Pricing();
  String _type = ParcelTypes.all[1];
  double _kg = 1;
  bool _collectCash = false;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _senderName = TextEditingController(text: widget.profile.name);
    _senderPhone = TextEditingController(text: widget.profile.phone);
    _cod.addListener(() => setState(() {}));
    _load();
  }

  Future<void> _load() async {
    final zones = await Backend.instance.serviceZones();
    final pricing = await Backend.instance.pricing();
    if (!mounted) return;
    setState(() {
      _zones = zones;
      _zone = zones.isNotEmpty ? zones.first : null;
      _pricing = pricing;
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final c in [_senderName, _senderPhone, _pickup, _dropoff, _receiverName, _receiverPhone, _cod, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _codAmount => _collectCash ? (double.tryParse(_cod.text.trim()) ?? 0) : 0;
  double get _fee => _zone == null ? 0 : _pricing.quote(_zone!, _kg, _codAmount);

  String? _required(String? v, String what) => (v == null || v.trim().isEmpty) ? 'Enter $what' : null;

  String? _phone(String? v) {
    final d = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length < 9) return 'Enter a valid mobile number';
    return null;
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      showMessage(context, 'Please fill in the highlighted fields.', error: true);
      return;
    }
    final zone = _zone;
    if (zone == null) return;
    if (_collectCash && _codAmount <= 0) {
      showMessage(context, 'Enter the cash amount to collect.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final order = await Backend.instance.createOrder(NewOrder(
        city: zone.name,
        pickupAddress: _pickup.text.trim(),
        dropoffAddress: _dropoff.text.trim(),
        senderName: _senderName.text.trim(),
        senderPhone: _senderPhone.text.trim(),
        receiverName: _receiverName.text.trim(),
        receiverPhone: _receiverPhone.text.trim(),
        parcelType: _type,
        weightKg: _kg,
        codAmount: _codAmount,
        deliveryFee: _fee,
        notes: _notes.text.trim(),
      ));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => OrderScreen(order: order, justBooked: true)));
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section(IconData icon, String title, Color color, List<Widget> children) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 12);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send a parcel')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
                children: [
                  if (_zones.length > 1) ...[
                    Wrap(
                      spacing: 8,
                      children: _zones
                          .map((z) => ChoiceChip(
                                label: Text(z.name),
                                selected: z.name == _zone?.name,
                                onSelected: (_) => setState(() => _zone = z),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _section(Icons.radio_button_checked, 'Pickup', AppColors.teal, [
                    TextFormField(
                      controller: _pickup,
                      maxLines: 2,
                      minLines: 1,
                      decoration: const InputDecoration(
                        labelText: 'Pickup address',
                        hintText: 'District, street, building, floor',
                      ),
                      validator: (v) => _required(v, 'the pickup address'),
                    ),
                    _gap(),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _senderName,
                          decoration: const InputDecoration(labelText: 'Sender name'),
                          validator: (v) => _required(v, 'a name'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _senderPhone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Sender mobile'),
                          validator: _phone,
                        ),
                      ),
                    ]),
                  ]),
                  const SizedBox(height: 12),
                  _section(Icons.location_on, 'Drop-off', AppColors.purple, [
                    TextFormField(
                      controller: _dropoff,
                      maxLines: 2,
                      minLines: 1,
                      decoration: const InputDecoration(
                        labelText: 'Drop-off address',
                        hintText: 'District, street, building, floor',
                      ),
                      validator: (v) => _required(v, 'the drop-off address'),
                    ),
                    _gap(),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _receiverName,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Receiver name'),
                          validator: (v) => _required(v, 'a name'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _receiverPhone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Receiver mobile', hintText: '05X XXX XXXX'),
                          validator: _phone,
                        ),
                      ),
                    ]),
                  ]),
                  const SizedBox(height: 12),
                  _section(Icons.inventory_2_outlined, 'Parcel', AppColors.warn, [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ParcelTypes.all
                          .map((t) => ChoiceChip(
                                label: Text(t),
                                selected: t == _type,
                                onSelected: (_) => setState(() => _type = t),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      const Text('Weight', style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${_kg.toStringAsFixed(_kg % 1 == 0 ? 0 : 1)} kg',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.purple)),
                    ]),
                    Slider(
                      value: _kg,
                      min: 0.5,
                      max: 30,
                      divisions: 59,
                      onChanged: (v) => setState(() => _kg = v),
                    ),
                    Text('First ${_pricing.freeKg.toStringAsFixed(0)} kg included.',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  ]),
                  const SizedBox(height: 12),
                  _section(Icons.payments_outlined, 'Cash on delivery', AppColors.ok, [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _collectCash,
                      onChanged: (v) => setState(() => _collectCash = v),
                      title: const Text('Driver collects cash from the receiver'),
                      subtitle: const Text('We add the cash to your MSI wallet after delivery.'),
                    ),
                    if (_collectCash)
                      TextFormField(
                        controller: _cod,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        decoration: const InputDecoration(labelText: 'Amount to collect', prefixText: '$kCurrency  '),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  _section(Icons.sticky_note_2_outlined, 'Note for the driver', AppColors.muted, [
                    TextFormField(
                      controller: _notes,
                      maxLines: 3,
                      minLines: 1,
                      decoration: const InputDecoration(hintText: 'Gate code, landmark, fragile…'),
                    ),
                  ]),
                ],
              ),
            ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: Offset(0, -4))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Delivery fee', style: TextStyle(color: AppColors.muted)),
                          Text(money(_fee),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text('Book delivery'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
