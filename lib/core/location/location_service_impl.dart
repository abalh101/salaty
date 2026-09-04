import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:salah_focus/core/errors/app_exception.dart';
import 'package:salah_focus/core/location/location_service.dart';
import 'package:salah_focus/features/prayer_times/domain/user_location.dart';

class LocationServiceImpl implements LocationService {
  final Geocoding _geocoding = Geocoding();

  @override
  Future<UserLocation> currentLocation(String deviceTimezoneId) async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const LocationException(
          'Standortdienste sind deaktiviert. Du kannst stattdessen eine Stadt auswählen.',
        );
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const LocationException(
          'Standortzugriff wurde nicht erlaubt. Du kannst eine Stadt manuell auswählen.',
        );
      }
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      String city = '';
      String country = '';
      try {
        final List<Placemark> placemarks =
            await _geocoding.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          city = placemarks.first.locality ??
              placemarks.first.subAdministrativeArea ??
              '';
          country = placemarks.first.country ?? '';
        }
      } on Object {
        // Fallback: Koordinaten beibehalten
      }

      return UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        city: city.isEmpty ? 'Aktueller Standort' : city,
        country: country,
        timezoneId: deviceTimezoneId,
        isAutomatic: true,
      );
    } on AppException {
      rethrow;
    } on Object catch (error) {
      throw LocationException('Standort konnte nicht ermittelt werden: $error');
    }
  }

  @override
  Future<UserLocation> geocodeManual({
    required String city,
    required String country,
    required String deviceTimezoneId,
  }) async {
    final String cleanedCity = city.trim();
    final String cleanedCountry = country.trim();
    if (cleanedCity.isEmpty || cleanedCountry.isEmpty) {
      throw const LocationException('Bitte Stadt und Land angeben.');
    }
    try {
      final List<Location> matches =
          await _geocoding.locationFromAddress('$cleanedCity, $cleanedCountry');
      if (matches.isEmpty) {
        throw const LocationException('Dieser Ort wurde nicht gefunden.');
      }
      final Location first = matches.first;
      return UserLocation(
        latitude: first.latitude,
        longitude: first.longitude,
        city: cleanedCity,
        country: cleanedCountry,
        timezoneId: deviceTimezoneId,
        isAutomatic: false,
      );
    } on AppException {
      rethrow;
    } on Object catch (error) {
      throw LocationException('Ort konnte nicht aufgelöst werden: $error');
    }
  }
}
