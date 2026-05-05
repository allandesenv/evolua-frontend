import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';

bool hasCheckInToday(
  Iterable<CheckIn> checkIns, {
  CheckIn? latestCreatedCheckIn,
  DateTime? now,
}) {
  final today = _localDay(now ?? DateTime.now());
  final candidates = [?latestCreatedCheckIn, ...checkIns];

  return candidates.any((checkIn) => _localDay(checkIn.createdAt) == today);
}

DateTime _localDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}
