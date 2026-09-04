import 'package:salah_focus/features/prayer_times/domain/user_location.dart';

abstract interface class LocationService {
  Future<UserLocation> currentLocation(String deviceTimezoneId);

  Future<UserLocation> geocodeManual({
    required String city,
    required String country,
    required String deviceTimezoneId,
  });
}
