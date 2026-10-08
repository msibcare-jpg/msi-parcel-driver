import 'package:flutter_test/flutter_test.dart';
import 'package:msi_parcel_customer/services/location_tools.dart';

void main() {
  test('reads coordinates from WhatsApp and Google Maps links', () async {
    final a = await LocationTools.fromText('https://maps.google.com/maps?q=21.543210,39.172800&z=17');
    expect(a.lat, closeTo(21.54321, 1e-6));
    expect(a.lng, closeTo(39.1728, 1e-6));

    final b = await LocationTools.fromText('https://www.google.com/maps/place/X/@21.5501,39.1802,17z/data=!3d21.5512!4d39.1811');
    expect(b.lat, closeTo(21.5512, 1e-6));

    final c = await LocationTools.fromText('21.6001, 39.2002');
    expect(c.lng, closeTo(39.2002, 1e-6));
  });
}
