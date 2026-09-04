class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.country,
    required this.timezoneId,
    required this.isAutomatic,
  });

  final double latitude;
  final double longitude;
  final String city;
  final String country;
  final String timezoneId;
  final bool isAutomatic;

  String get label => city.isEmpty ? country : '$city, $country';

  Map<String, Object?> toJson() => <String, Object?>{
        'latitude': latitude,
        'longitude': longitude,
        'city': city,
        'country': country,
        'timezoneId': timezoneId,
        'isAutomatic': isAutomatic,
      };

  factory UserLocation.fromJson(Map<String, Object?> json) {
    final double latitude = (json['latitude']! as num).toDouble();
    final double longitude = (json['longitude']! as num).toDouble();
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException('Invalid stored coordinates.');
    }
    final String timezoneId = ((json['timezoneId'] as String?) ?? 'UTC').trim();
    return UserLocation(
      latitude: latitude,
      longitude: longitude,
      city: ((json['city'] as String?) ?? '').trim(),
      country: ((json['country'] as String?) ?? '').trim(),
      timezoneId: timezoneId.isEmpty ? 'UTC' : timezoneId,
      isAutomatic: (json['isAutomatic'] as bool?) ?? false,
    );
  }
}
