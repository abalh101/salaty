import 'dart:math' as math;

class QiblaCalculator {
  const QiblaCalculator._();

  static const double kaabaLatitude = 21.422487;
  static const double kaabaLongitude = 39.826206;

  static double bearing({required double latitude, required double longitude}) {
    final double lat1 = _radians(latitude);
    final double lat2 = _radians(kaabaLatitude);
    final double deltaLongitude = _radians(kaabaLongitude - longitude);
    final double y = math.sin(deltaLongitude) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLongitude);
    return (_degrees(math.atan2(y, x)) + 360) % 360;
  }

  static double relativeAngle({required double qiblaBearing, required double heading}) {
    double angle = qiblaBearing - heading;
    while (angle > 180) angle -= 360;
    while (angle < -180) angle += 360;
    return angle;
  }

  static double _radians(double value) => value * math.pi / 180;
  static double _degrees(double value) => value * 180 / math.pi;
}
