import 'package:evolua_frontend/features/emotional/application/check_in_day.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hasCheckInToday', () {
    test('returns true when history has a check-in on the local day', () {
      final now = DateTime(2026, 5, 5, 10);

      expect(
        hasCheckInToday([_checkIn(DateTime(2026, 5, 5, 8))], now: now),
        isTrue,
      );
    });

    test('returns true when latest created check-in is today', () {
      final now = DateTime(2026, 5, 5, 10);

      expect(
        hasCheckInToday(
          [_checkIn(DateTime(2026, 5, 4, 22))],
          latestCreatedCheckIn: _checkIn(DateTime(2026, 5, 5, 9)),
          now: now,
        ),
        isTrue,
      );
    });

    test('returns false when only older check-ins exist', () {
      final now = DateTime(2026, 5, 5, 10);

      expect(
        hasCheckInToday([_checkIn(DateTime(2026, 5, 4, 23))], now: now),
        isFalse,
      );
    });
  });
}

CheckIn _checkIn(DateTime createdAt) {
  return CheckIn(
    id: 1,
    userId: 'user-123',
    mood: 'calmo',
    reflection: '',
    energyLevel: 7,
    recommendedPractice: '',
    aiInsight: null,
    createdAt: createdAt,
  );
}
