import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'backend.dart';

enum LocationResult { ok, serviceOff, denied, deniedForever }

/// Sends the driver's position to the server while they are online.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  StreamSubscription<Position>? _sub;

  bool get isRunning => _sub != null;

  Future<LocationResult> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationResult.serviceOff;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.deniedForever) return LocationResult.deniedForever;
    if (p == LocationPermission.always || p == LocationPermission.whileInUse) {
      return LocationResult.ok;
    }
    return LocationResult.denied;
  }

  Future<LocationResult> start() async {
    final r = await ensurePermission();
    if (r != LocationResult.ok) return r;
    await _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      ),
    ).listen(
      (p) {
        Backend.instance
            .pushLocation(
              lat: p.latitude,
              lng: p.longitude,
              heading: p.heading,
              speed: p.speed,
            )
            .catchError((_) {});
      },
      onError: (_) {},
    );
    return LocationResult.ok;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> openSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
