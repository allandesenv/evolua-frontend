import 'dart:typed_data';

import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/app_theme.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_progress.dart';
import 'package:evolua_frontend/features/content/domain/repositories/trail_repository.dart';
import 'package:evolua_frontend/features/content/presentation/widgets/content_module_view.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/features/user/domain/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ContentModuleView mobile trails navigation', () {
    testWidgets('shows journey and catalog switcher on compact width', (
      tester,
    ) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('Minha jornada'), findsOneWidget);
      expect(find.text('Catalogo'), findsOneWidget);
      expect(find.text('Ver catalogo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens catalog even when an active journey exists', (
      tester,
    ) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Catalogo'));
      await tester.pumpAndSettle();

      expect(find.text('Encontrar uma trilha certa'), findsOneWidget);
      expect(find.text('Respiracao breve'), findsOneWidget);
      expect(find.text('Minha jornada ativa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens catalog from active journey action', (tester) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ver catalogo'));
      await tester.pumpAndSettle();

      expect(find.text('Encontrar uma trilha certa'), findsOneWidget);
      expect(find.text('Respiracao breve'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses light surfaces and readable text in light theme', (
      tester,
    ) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(
        _testApp(theme: AppTheme.light(accessibleFont: true)),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Minha jornada'));
      final colors = context.evoluaColors;
      final panel = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      final decoration = panel.decoration! as BoxDecoration;

      expect(Theme.of(context).brightness, Brightness.light);
      expect(decoration.color, colors.surface.withValues(alpha: 0.94));
      expect(
        decoration.color,
        isNot(AppColors.surface.withValues(alpha: 0.94)),
      );
      expect(
        Theme.of(context).textTheme.bodyMedium?.color,
        isNot(AppColors.textSecondary),
      );
    });
  });
}

Future<void> _setCompactSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 820));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _testApp({ThemeData? theme}) {
  SharedPreferences.setMockInitialValues({});

  return ProviderScope(
    overrides: [
      trailRepositoryProvider.overrideWithValue(_FakeTrailRepository()),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.dark(),
      home: const Scaffold(
        body: SizedBox.expand(child: ContentModuleView(showSectionChips: true)),
      ),
    ),
  );
}

class _FakeTrailRepository implements TrailRepository {
  _FakeTrailRepository()
    : _activeTrail = _trail(
        id: 1,
        title: 'Clareza em 8 minutos',
        summary: 'Uma jornada ativa para organizar o momento.',
        activeJourney: true,
        generatedByAi: true,
      ),
      _catalogTrail = _trail(
        id: 2,
        title: 'Respiracao breve',
        summary: 'Uma trilha curta para voltar ao corpo.',
        activeJourney: false,
        generatedByAi: false,
      );

  final Trail _activeTrail;
  final Trail _catalogTrail;

  @override
  Future<Trail?> currentJourney() async => _activeTrail;

  @override
  Future<PaginatedResponse<Trail>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? category,
    bool? premium,
  }) async {
    return PaginatedResponse(
      items: [_catalogTrail],
      page: page,
      size: size,
      totalItems: 1,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      sortBy: sortBy,
      sortDir: sortDir,
      filters: const {},
    );
  }

  @override
  Future<TrailJourney> journey(int trailId) async {
    final trail = trailId == _activeTrail.id ? _activeTrail : _catalogTrail;
    return _journey(trail);
  }

  @override
  Future<TrailJourney> startJourney(int trailId) async {
    return journey(trailId);
  }

  @override
  Future<TrailJourney> completeStep(int trailId, int stepIndex) async {
    return journey(trailId);
  }

  @override
  Future<Trail> create({
    required String title,
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(int id) {
    throw UnimplementedError();
  }

  @override
  Future<Trail> update({
    required int id,
    required String title,
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
  }) {
    throw UnimplementedError();
  }
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<Profile?> getMe() async => null;

  @override
  Future<Profile> upsertMe({
    required String displayName,
    required DateTime birthDate,
    required String gender,
    String? customGender,
    required String bio,
    required int journeyLevel,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) {
    throw UnimplementedError();
  }
}

Trail _trail({
  required int id,
  required String title,
  required String summary,
  required bool activeJourney,
  required bool generatedByAi,
}) {
  return Trail(
    id: id,
    userId: 'user-123',
    title: title,
    summary: summary,
    content: 'Respire, nomeie e escolha.',
    category: 'clareza',
    premium: false,
    privateTrail: false,
    activeJourney: activeJourney,
    generatedByAi: generatedByAi,
    journeyKey: 'clareza',
    sourceStyle: 'briefing',
    accessible: true,
    mediaLinks: const [],
    createdAt: DateTime(2026, 1, 1),
  );
}

TrailJourney _journey(Trail trail) {
  final steps = [
    const TrailJourneyStep(
      index: 0,
      title: 'Respirar',
      summary: 'Dois minutos de presenca.',
      content: 'Respire por quatro ciclos.',
      status: 'current',
      estimatedMinutes: 2,
      mediaLinks: [],
    ),
    const TrailJourneyStep(
      index: 1,
      title: 'Escolher',
      summary: 'Uma proxima acao simples.',
      content: 'Escolha uma acao pequena.',
      status: 'pending',
      estimatedMinutes: 4,
      mediaLinks: [],
    ),
  ];

  return TrailJourney(
    trail: trail,
    steps: steps,
    progress: TrailProgress(
      currentStepIndex: 0,
      completedStepIndexes: const [],
      startedAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      completedAt: null,
    ),
    progressPercent: 0,
    nextStep: steps.first,
  );
}
