import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/driver_profile.dart';
import '../services/backend.dart';
import '../ui/kit.dart';
import '../widgets/order_widgets.dart';

/// Driver sign-up: personal details, vehicle and three photos.
/// After sending, the office reviews and approves the driver.
class RegisterScreen extends StatefulWidget {
  /// When a rejected driver edits and resends, their old details are filled in.
  final DriverProfile? previous;
  const RegisterScreen({super.key, this.previous});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _idNumber;
  late final TextEditingController _plate;
  String? _city;
  String _vehicle = VehicleTypes.all.first;
  List<String> _cities = const [];
  bool _loadingCities = true;
  File? _license;
  File? _vehiclePhoto;
  File? _selfie;
  bool _agreed = false;
  bool _busy = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final p = widget.previous;
    _name = TextEditingController(text: p?.name ?? '');
    _idNumber = TextEditingController(text: p?.idNumber ?? '');
    _plate = TextEditingController(text: p?.plateNumber ?? '');
    if (p != null && VehicleTypes.all.contains(p.vehicleType)) _vehicle = p.vehicleType;
    _loadCities(p?.city);
  }

  Future<void> _loadCities(String? preferred) async {
    final list = await Backend.instance.serviceCities();
    if (!mounted) return;
    setState(() {
      _cities = list;
      _loadingCities = false;
      _city = (preferred != null && list.contains(preferred))
          ? preferred
          : (list.isNotEmpty ? list.first : null);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _idNumber.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<File?> _pick({bool selfie = false}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            if (!selfie)
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    try {
      final x = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1600,
        preferredCameraDevice: selfie ? CameraDevice.front : CameraDevice.rear,
      );
      return x == null ? null : File(x.path);
    } catch (e) {
      if (mounted) showMessage(context, 'Could not open the camera. Allow camera access in Settings.', error: true);
      return null;
    }
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_city == null) {
      showMessage(context, 'Choose your city.', error: true);
      return;
    }
    final license = _license;
    final vehicle = _vehiclePhoto;
    final selfie = _selfie;
    if (license == null || vehicle == null || selfie == null) {
      showMessage(context, 'Add all three photos.', error: true);
      return;
    }
    if (!_agreed) {
      showMessage(context, 'Please confirm that your details are correct.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await Backend.instance.submitRegistration(
        DriverRegistration(
          name: _name.text.trim(),
          idNumber: _idNumber.text.trim(),
          city: _city!,
          vehicleType: _vehicle,
          plateNumber: _plate.text.trim().toUpperCase(),
        ),
        licensePhoto: license,
        vehiclePhoto: vehicle,
        selfie: selfie,
      );
      if (!mounted) return;
      // When opened from the Pending screen, go back to it.
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _chips(List<String> options, String? selected, ValueChanged<String> onSelect) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map((o) => ChoiceChip(
                label: Text(o),
                selected: o == selected,
                onSelected: _busy ? null : (_) => setState(() => onSelect(o)),
              ))
          .toList(),
    );
  }

  Widget _photoTile(String title, String hint, File? file, VoidCallback onTap) {
    return InkWell(
      onTap: _busy ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Panel(
        padding: const EdgeInsets.all(12),
        borderColor: file == null ? AppColors.line : AppColors.teal,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 64,
                height: 64,
                color: AppColors.purpleSoft,
                child: file == null
                    ? const Icon(Icons.add_a_photo_outlined, color: AppColors.purple)
                    : Image.file(file, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(file == null ? hint : 'Added. Tap to change.',
                      style: TextStyle(color: file == null ? AppColors.muted : AppColors.teal, fontSize: 13)),
                ],
              ),
            ),
            Icon(file == null ? Icons.chevron_right : Icons.check_circle,
                color: file == null ? AppColors.muted : AppColors.teal),
          ],
        ),
      ),
    );
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? 'Enter your $label' : null;

  @override
  Widget build(BuildContext context) {
    final resubmit = widget.previous != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(resubmit ? 'Update application' : 'Become an MSI driver'),
        actions: [
          if (!resubmit)
            TextButton(
              onPressed: _busy ? null : () => Backend.instance.signOut(),
              child: const Text('Sign out'),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (Backend.instance.isDemo) ...[
                const DemoBanner('Demo mode: your application stays on this phone.'),
                const SizedBox(height: 16),
              ],
              const Text('Your details', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name (as on your ID)'),
                validator: (v) => _required(v, 'full name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _idNumber,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Iqama / National ID number'),
                validator: (v) {
                  final r = _required(v, 'ID number');
                  if (r != null) return r;
                  final digits = v!.replaceAll(RegExp(r'[^0-9]'), '');
                  return digits.length < 8 ? 'ID number looks too short' : null;
                },
              ),
              const SizedBox(height: 20),
              const Text('City you will work in', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _loadingCities
                  ? const LinearProgressIndicator()
                  : _chips(_cities, _city, (c) => _city = c),
              const SizedBox(height: 20),
              const Text('Vehicle', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _chips(VehicleTypes.all, _vehicle, (v) => _vehicle = v),
              const SizedBox(height: 12),
              TextFormField(
                controller: _plate,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Plate number'),
                validator: (v) => _required(v, 'plate number'),
              ),
              const SizedBox(height: 24),
              const Text('Photos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Clear photos help us approve you faster.', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              _photoTile('Driving license', 'Front side, all text readable', _license, () async {
                final f = await _pick();
                if (f != null && mounted) setState(() => _license = f);
              }),
              const SizedBox(height: 10),
              _photoTile('Vehicle', 'Show the plate number', _vehiclePhoto, () async {
                final f = await _pick();
                if (f != null && mounted) setState(() => _vehiclePhoto = f);
              }),
              const SizedBox(height: 10),
              _photoTile('Your photo', 'A clear selfie, face visible', _selfie, () async {
                final f = await _pick(selfie: true);
                if (f != null && mounted) setState(() => _selfie = f);
              }),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _agreed,
                onChanged: _busy ? null : (v) => setState(() => _agreed = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('My details are correct and I agree to the MSI Parcel driver terms.'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                          SizedBox(width: 12),
                          Text('Sending…'),
                        ],
                      )
                    : Text(resubmit ? 'Send again' : 'Send application'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
