import 'package:flutter/widgets.dart';
import 'package:salah_focus/app/localization/app_strings.dart';
import 'package:salah_focus/core/errors/app_exception.dart';

String userErrorMessage(BuildContext context, Object error) {
  final AppStrings s = AppStrings.of(context);
  return switch (error) {
    LocationException() => s.t('locationError'),
    NetworkException() => s.t('networkError'),
    PrayerDataException() => s.t('prayerDataError'),
    AppException() => s.t('genericError'),
    _ => s.t('genericError'),
  };
}
