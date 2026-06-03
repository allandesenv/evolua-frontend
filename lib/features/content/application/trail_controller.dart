import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/content/data/repositories/trail_repository_impl.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step_response.dart';
import 'package:evolua_frontend/features/content/domain/repositories/trail_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final trailRepositoryProvider = Provider<TrailRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.contentBaseUrl));
  return TrailRepositoryImpl(dio);
});

final trailControllerProvider =
    AsyncNotifierProvider<TrailController, PaginatedResponse<Trail>>(
      TrailController.new,
    );

final trailCatalogLoadMoreStateProvider =
    NotifierProvider<TrailCatalogLoadMoreController, TrailCatalogLoadMoreState>(
      TrailCatalogLoadMoreController.new,
    );

class TrailCatalogLoadMoreState {
  const TrailCatalogLoadMoreState({
    this.isLoadingMore = false,
    this.loadMoreError = false,
  });

  final bool isLoadingMore;
  final bool loadMoreError;
}

class TrailCatalogLoadMoreController
    extends Notifier<TrailCatalogLoadMoreState> {
  @override
  TrailCatalogLoadMoreState build() => const TrailCatalogLoadMoreState();

  void loading() {
    state = const TrailCatalogLoadMoreState(isLoadingMore: true);
  }

  void error() {
    state = const TrailCatalogLoadMoreState(loadMoreError: true);
  }

  void reset() {
    state = const TrailCatalogLoadMoreState();
  }
}

final currentJourneyTrailProvider = FutureProvider<Trail?>((ref) async {
  return ref.watch(trailRepositoryProvider).currentJourney();
});

final inProgressTrailJourneysProvider = FutureProvider<List<TrailJourney>>((
  ref,
) async {
  return ref.watch(trailRepositoryProvider).listInProgressJourneys();
});

final trailJourneyProvider = FutureProvider.family<TrailJourney, int>((
  ref,
  trailId,
) async {
  return ref.watch(trailRepositoryProvider).journey(trailId);
});

typedef TrailStepResponseKey = ({String userId, int trailId, int stepIndex});

final trailStepResponseProvider =
    FutureProvider.family<TrailStepResponse?, TrailStepResponseKey>((
      ref,
      key,
    ) async {
      return ref
          .watch(trailRepositoryProvider)
          .stepResponse(trailId: key.trailId, stepIndex: key.stepIndex);
    });

final trailStepResponsesProvider = FutureProvider<List<TrailStepResponse>>((
  ref,
) async {
  return ref.watch(trailRepositoryProvider).listStepResponses();
});

final trailJourneyActionProvider = Provider<TrailJourneyActions>((ref) {
  return TrailJourneyActions(ref);
});

class TrailJourneyActions {
  const TrailJourneyActions(this._ref);

  final Ref _ref;

  Future<TrailJourney> start(int trailId) async {
    final journey = await _ref
        .read(trailRepositoryProvider)
        .startJourney(trailId);
    _ref.invalidate(trailJourneyProvider(trailId));
    _ref.invalidate(currentJourneyTrailProvider);
    _ref.invalidate(inProgressTrailJourneysProvider);
    return journey;
  }

  Future<TrailJourney> completeStep(int trailId, int stepIndex) async {
    final journey = await _ref
        .read(trailRepositoryProvider)
        .completeStep(trailId, stepIndex);
    _ref.invalidate(trailJourneyProvider(trailId));
    _ref.invalidate(currentJourneyTrailProvider);
    _ref.invalidate(inProgressTrailJourneysProvider);
    return journey;
  }

  Future<TrailJourney> updateVideoProgress({
    required int trailId,
    required int stepIndex,
    required int watchedSeconds,
    required int durationSeconds,
  }) async {
    final journey = await _ref
        .read(trailRepositoryProvider)
        .updateVideoProgress(
          trailId: trailId,
          stepIndex: stepIndex,
          watchedSeconds: watchedSeconds,
          durationSeconds: durationSeconds,
        );
    _ref.invalidate(trailJourneyProvider(trailId));
    _ref.invalidate(currentJourneyTrailProvider);
    _ref.invalidate(inProgressTrailJourneysProvider);
    return journey;
  }

  Future<TrailStepResponse> saveStepResponse({
    required String userId,
    required int trailId,
    required int stepIndex,
    required String responseText,
  }) async {
    final session = _ref.read(authControllerProvider).asData?.value;
    if (session == null || session.userId != userId) {
      throw StateError('Sessao invalida para salvar resposta da trilha.');
    }

    final response = await _ref
        .read(trailRepositoryProvider)
        .saveStepResponse(
          trailId: trailId,
          stepIndex: stepIndex,
          responseText: responseText,
        );
    _ref.invalidate(
      trailStepResponseProvider((
        userId: userId,
        trailId: trailId,
        stepIndex: stepIndex,
      )),
    );
    _ref.invalidate(trailStepResponsesProvider);
    return response;
  }
}

class TrailController extends AsyncNotifier<PaginatedResponse<Trail>> {
  static const _pageSize = 4;
  String? _search;
  bool? _premium;
  String? _category;

  @override
  Future<PaginatedResponse<Trail>> build() async {
    return _fetch(page: 0);
  }

  Future<void> refresh() async {
    _resetLoadMoreState();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: 0));
  }

  Future<void> applyFilters({
    String? search,
    bool? premium,
    String? category,
  }) async {
    _search = search;
    _premium = premium;
    _category = category;
    _resetLoadMoreState();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: 0));
  }

  Future<void> goToPage(int page) async {
    _resetLoadMoreState();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: page));
  }

  Future<void> loadNextPage() async {
    final current = state.asData?.value;
    final loadMoreState = ref.read(trailCatalogLoadMoreStateProvider);
    if (current == null || !current.hasNext || loadMoreState.isLoadingMore) {
      return;
    }

    ref.read(trailCatalogLoadMoreStateProvider.notifier).loading();

    try {
      final next = await _fetch(page: current.page + 1);
      final merged = <int, Trail>{
        for (final trail in current.items) trail.id: trail,
      };
      for (final trail in next.items) {
        merged.putIfAbsent(trail.id, () => trail);
      }
      state = AsyncData(next.copyWith(items: merged.values.toList()));
      _resetLoadMoreState();
    } catch (_) {
      ref.read(trailCatalogLoadMoreStateProvider.notifier).error();
    }
  }

  Future<void> create({
    required String title,
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
    required List<TrailStep> steps,
  }) async {
    final repository = ref.read(trailRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.create(
        title: title,
        summary: summary,
        content: content,
        category: category,
        premium: premium,
        mediaLinks: mediaLinks,
        steps: steps,
      );

      return _fetch(page: 0);
    });
  }

  Future<void> updateTrail({
    required int id,
    required String title,
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
    required List<TrailStep> steps,
  }) async {
    final repository = ref.read(trailRepositoryProvider);
    final currentPage = state.asData?.value.page ?? 0;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.update(
        id: id,
        title: title,
        summary: summary,
        content: content,
        category: category,
        premium: premium,
        mediaLinks: mediaLinks,
        steps: steps,
      );

      ref.invalidate(trailJourneyProvider(id));
      ref.invalidate(currentJourneyTrailProvider);
      ref.invalidate(inProgressTrailJourneysProvider);
      return _fetch(page: currentPage);
    });
  }

  Future<void> delete(int id) async {
    final repository = ref.read(trailRepositoryProvider);
    final currentPage = state.asData?.value.page ?? 0;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.delete(id);
      ref.invalidate(trailJourneyProvider(id));
      ref.invalidate(currentJourneyTrailProvider);
      ref.invalidate(inProgressTrailJourneysProvider);
      return _fetch(page: currentPage);
    });
  }

  Future<PaginatedResponse<Trail>> _fetch({required int page}) {
    return ref
        .read(trailRepositoryProvider)
        .list(
          page: page,
          size: _pageSize,
          search: _search,
          premium: _premium,
          category: _category,
        );
  }

  void _resetLoadMoreState() {
    ref.read(trailCatalogLoadMoreStateProvider.notifier).reset();
  }
}
