import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/emotional/domain/repositories/check_in_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hydrates latest created check-in from initial history', () async {
    final latest = _checkIn(
      id: 10,
      createdAt: DateTime(2026, 5, 5, 10),
      aiInsight: _insight(),
    );
    final previous = _checkIn(
      id: 9,
      createdAt: DateTime(2026, 5, 4, 10),
      aiInsight: null,
    );
    final container = ProviderContainer(
      overrides: [
        checkInRepositoryProvider.overrideWithValue(
          _FakeCheckInRepository([latest, previous]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(checkInControllerProvider.future);

    expect(state.latestCreatedCheckIn, same(latest));
    expect(state.latestCreatedCheckIn?.aiInsight?.insight, 'Leitura salva.');
  });
}

class _FakeCheckInRepository implements CheckInRepository {
  const _FakeCheckInRepository(this.items);

  final List<CheckIn> items;

  @override
  Future<PaginatedResponse<CheckIn>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? mood,
    String? energyRange,
    DateTime? from,
    DateTime? to,
  }) async {
    return PaginatedResponse(
      items: items,
      page: page,
      size: size,
      totalItems: items.length,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      sortBy: sortBy,
      sortDir: sortDir,
      filters: const {},
    );
  }

  @override
  Future<CheckIn> create({
    required String mood,
    String? reflection,
    required int energyLevel,
  }) {
    throw UnimplementedError();
  }
}

CheckIn _checkIn({
  required int id,
  required DateTime createdAt,
  required CheckInAiInsight? aiInsight,
}) {
  return CheckIn(
    id: id,
    userId: 'user-123',
    mood: 'calmo',
    reflection: '',
    energyLevel: 7,
    recommendedPractice: '',
    aiInsight: aiInsight,
    createdAt: createdAt,
  );
}

CheckInAiInsight _insight() {
  return const CheckInAiInsight(
    insight: 'Leitura salva.',
    suggestedAction: 'Respire por dois minutos.',
    riskLevel: 'low',
    suggestedTrailId: null,
    suggestedTrailTitle: null,
    suggestedTrailReason: '',
    suggestedSpace: null,
    journeyPlan: null,
    generatedTrailDraft: null,
    fallbackUsed: false,
  );
}
