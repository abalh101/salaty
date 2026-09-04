abstract interface class ClockService {
  DateTime nowUtc();
}

class SystemClockService implements ClockService {
  const SystemClockService();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}
