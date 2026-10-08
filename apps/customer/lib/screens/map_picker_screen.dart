import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_tools.dart';
import '../ui/kit.dart';

/// Full-screen map with a pin in the middle. Move the map, then confirm.
class MapPickerScreen extends StatefulWidget {
  final String title;
  final PlacePin? start;
  const MapPickerScreen({super.key, required this.title, this.start});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  // Jeddah city centre, used when nothing else is known.
  static const _fallback = LatLng(21.5433, 39.1728);
  final _map = MapController();
  late LatLng _center;
  String _address = '';
  bool _looking = false;
  bool _locating = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final s = widget.start;
    _center = s == null ? _fallback : LatLng(s.lat, s.lng);
    _lookup();
    if (s == null) _goToMe(silent: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _moved(LatLng c) {
    _center = c;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _lookup);
    setState(() {});
  }

  Future<void> _lookup() async {
    setState(() => _looking = true);
    final c = _center;
    final a = await LocationTools.addressOf(c.latitude, c.longitude);
    if (!mounted || c != _center) return;
    setState(() {
      _address = a;
      _looking = false;
    });
  }

  Future<void> _goToMe({bool silent = false}) async {
    setState(() => _locating = true);
    try {
      final p = await LocationTools.current();
      if (!mounted) return;
      _center = LatLng(p.lat, p.lng);
      try {
        _map.move(_center, 17);
      } catch (_) {}
      _lookup();
    } catch (e) {
      if (!silent && mounted) showMessage(context, '$e'.replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.start == null ? 12 : 17,
              onPositionChanged: (camera, hasGesture) => _moved(camera.center),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.msibusinesscare.msi_parcel_customer',
              ),
              RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
            ],
          ),
          // The pin sits in the middle; its tip marks the chosen point.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: Icon(Icons.location_on, size: 48, color: AppColors.purple),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 190,
            child: FloatingActionButton(
              heroTag: 'me',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.purple,
              onPressed: _locating ? null : () => _goToMe(),
              child: _locating
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 24, offset: Offset(0, 8))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Icon(Icons.place_outlined, color: AppColors.purple),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _looking ? 'Finding address…' : (_address.isEmpty ? 'Pinned location' : _address),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)} · move the map to adjust',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(PlacePin(_center.latitude, _center.longitude, _address)),
                      child: const Text('Use this location'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
