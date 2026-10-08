import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// A pinned place: exact coordinates plus a readable address when known.
class PlacePin {
  final double lat;
  final double lng;
  final String address;
  const PlacePin(this.lat, this.lng, [this.address = '']);

  String get short => '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}

class LocationTools {
  /// Current GPS position, or throws a message the customer can read.
  static Future<PlacePin> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Turn on location (GPS) on your phone.');
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      throw Exception('Allow location access for MSI Parcel in Settings.');
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).timeout(const Duration(seconds: 20));
    return PlacePin(pos.latitude, pos.longitude);
  }

  static final _patterns = <RegExp>[
    RegExp(r'!3d(-?\d{1,2}\.\d+)!4d(-?\d{1,3}\.\d+)'),
    RegExp(r'[?&](?:q|query|ll|destination|daddr|center|sll)=(?:loc:)?(-?\d{1,2}\.\d+)\s*(?:,|%2C)\s*(-?\d{1,3}\.\d+)'),
    RegExp(r'@(-?\d{1,2}\.\d+),(-?\d{1,3}\.\d+)'),
    RegExp(r'geo:(-?\d{1,2}\.\d+),(-?\d{1,3}\.\d+)'),
    RegExp(r'(-?\d{1,2}\.\d{3,})\s*,\s*(-?\d{1,3}\.\d{3,})'),
  ];

  static PlacePin? _match(String text) {
    for (final re in _patterns) {
      final m = re.firstMatch(text);
      if (m != null) {
        final lat = double.tryParse(m.group(1)!);
        final lng = double.tryParse(m.group(2)!);
        if (lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180) {
          return PlacePin(lat, lng);
        }
      }
    }
    return null;
  }

  /// Reads a location from a WhatsApp / Google Maps link or "lat, lng" text.
  /// Short links (maps.app.goo.gl, goo.gl/maps) are opened to find the pin.
  static Future<PlacePin> fromText(String raw) async {
    final text = Uri.decodeFull(raw.trim());
    final direct = _match(text);
    if (direct != null) return direct;

    final link = RegExp(r'https?://\S+').firstMatch(text)?.group(0);
    if (link == null) {
      throw Exception('Paste a Google Maps or WhatsApp location link.');
    }
    var url = Uri.parse(link);
    final client = http.Client();
    try {
      for (var hop = 0; hop < 5; hop++) {
        final req = http.Request('GET', url)..followRedirects = false;
        req.headers['User-Agent'] = 'Mozilla/5.0 (Linux; Android 14) MSIParcel/1.0';
        final res = await client.send(req).timeout(const Duration(seconds: 12));
        final loc = res.headers['location'];
        if (loc != null) {
          final found = _match(Uri.decodeFull(loc));
          if (found != null) return found;
          url = url.resolve(loc);
          continue;
        }
        final body = await res.stream.bytesToString();
        final found = _match(url.toString()) ?? _match(body);
        if (found != null) return found;
        break;
      }
    } finally {
      client.close();
    }
    throw Exception('Could not read a location from this link. Try "Pick on map".');
  }

  /// Street / district name for a pin (OpenStreetMap). Empty if unavailable.
  static Future<String> addressOf(double lat, double lng) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '$lat',
        'lon': '$lng',
        'zoom': '17',
        'accept-language': 'en',
      });
      final res = await http.get(uri, headers: {'User-Agent': 'MSI-Parcel-App/1.0 (msibusinesscare)'}).timeout(
        const Duration(seconds: 10),
      );
      if (res.statusCode != 200) return '';
      final data = jsonDecode(res.body);
      if (data is! Map) return '';
      final a = data['address'];
      if (a is Map) {
        final parts = <String>[
          for (final k in ['road', 'neighbourhood', 'suburb', 'city_district', 'city', 'town'])
            if (a[k] != null && '${a[k]}'.isNotEmpty) '${a[k]}',
        ];
        final unique = <String>[];
        for (final p in parts) {
          if (!unique.contains(p)) unique.add(p);
        }
        if (unique.isNotEmpty) return unique.take(3).join(', ');
      }
      return (data['display_name'] ?? '').toString().split(',').take(3).join(',').trim();
    } catch (_) {
      return '';
    }
  }
}
