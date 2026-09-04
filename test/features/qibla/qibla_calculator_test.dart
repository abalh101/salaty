import 'package:flutter_test/flutter_test.dart';
import 'package:salah_focus/features/qibla/domain/qibla_calculator.dart';

void main() {
  test('bearing always stays in compass range', () {
    final double bearing = QiblaCalculator.bearing(latitude: 51.2277, longitude: 6.7735);
    expect(bearing, greaterThanOrEqualTo(0));
    expect(bearing, lessThan(360));
  });

  test('relative angle chooses shortest rotation', () {
    expect(QiblaCalculator.relativeAngle(qiblaBearing: 10, heading: 350), closeTo(20, 0.001));
    expect(QiblaCalculator.relativeAngle(qiblaBearing: 350, heading: 10), closeTo(-20, 0.001));
  });
}
