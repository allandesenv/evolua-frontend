import 'dart:async';

import 'package:evolua_frontend/core/cache/stable_resource_cache.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/content/data/models/trail_summary_dto.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/content/data/repositories/trail_repository_impl.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step_response.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_summary.dart';
import 'package:evolua_frontend/features/content/domain/repositories/trail_repository.dart';
import 'package:evolua_frontend/features/notification/application/engagement_notification_planner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final trailRepositoryProvider = Provider<TrailRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.contentBaseUrl));
  return TrailRepositoryImpl(dio);
});

final trailControllerProvider =
    AsyncNotifierProvider<TrailController, PaginatedResponse<TrailSummary>>(
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

typedef TrailDetailKey = ({String userId, int trailId});

final trailDetailProvider = FutureProvider.autoDispose
    .family<Trail, TrailDetailKey>((ref, key) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 2), link.close);
      ref.onDispose(() {
        timer.cancel();
      });
      final session = ref.watch(authControllerProvider).asData?.value;
      if (session == null || session.userId != key.userId) {
        throw StateError('Sessao invalida para carregar detalhe da trilha.');
      }
      return ref.watch(trailRepositoryProvider).detail(key.trailId);
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

Future<void> invalidateTrailCatalogCache(Ref ref) async {
  try {
    final cache = await ref.read(stableResourceCacheProvider.future);
    await cache.invalidateResource(StableResource.trailCatalog);
  } catch (_) {
    // Cache invalidation must not fail the product action.
  }
}

Future<void> invalidateTrailCatalogCacheForCurrentUser(Ref ref) async {
  final userId = ref.read(authControllerProvider).asData?.value?.userId;
  if (userId == null || userId.isEmpty) {
    return;
  }
  try {
    final cache = await ref.read(stableResourceCacheProvider.future);
    await cache.invalidateUserResource(
      resource: StableResource.trailCatalog,
      userId: userId,
    );
  } catch (_) {
    // Cache invalidation must not fail the product action.
  }
}

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
    await invalidateTrailCatalogCacheForCurrentUser(_ref);
    unawaited(
      _ref
          .read(engagementNotificationPlannerProvider)
          .onTrailJourneyChanged(journey),
    );
    return journey;
  }

  Future<TrailJourney> completeStep(int trailId, int stepIndex) async {
    final journey = await _ref
        .read(trailRepositoryProvider)
        .completeStep(trailId, stepIndex);
    _ref.invalidate(trailJourneyProvider(trailId));
    _ref.invalidate(currentJourneyTrailProvider);
    _ref.invalidate(inProgressTrailJourneysProvider);
    await invalidateTrailCatalogCacheForCurrentUser(_ref);
    unawaited(
      _ref
          .read(engagementNotificationPlannerProvider)
          .onTrailJourneyChanged(journey),
    );
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
    await invalidateTrailCatalogCacheForCurrentUser(_ref);
    unawaited(
      _ref
          .read(engagementNotificationPlannerProvider)
          .onTrailJourneyChanged(journey),
    );
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

class TrailController extends AsyncNotifier<PaginatedResponse<TrailSummary>> {
  static const _pageSize = 4;
  static const _minimumSearchLength = 4;
  String? _search;
  bool? _premium;
  String? _category;

  @override
  Future<PaginatedResponse<TrailSummary>> build() async {
    return _fetch(page: 0);
  }

  Future<void> refresh() async {
    _resetLoadMoreState();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: 0, force: true));
  }

  Future<void> applyFilters({
    String? search,
    bool? premium,
    String? category,
  }) async {
    final normalizedSearch = search?.trim();
    final effectiveSearch =
        normalizedSearch != null &&
            normalizedSearch.length >= _minimumSearchLength
        ? normalizedSearch
        : null;
    final effectiveCategory = category?.trim();
    final normalizedCategory =
        effectiveCategory == null || effectiveCategory.isEmpty
        ? null
        : effectiveCategory;

    if (_search == effectiveSearch &&
        _premium == premium &&
        _category == normalizedCategory) {
      return;
    }

    _search = effectiveSearch;
    _premium = premium;
    _category = normalizedCategory;
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
      final merged = <int, TrailSummary>{
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

      await invalidateTrailCatalogCache(ref);
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
      await invalidateTrailCatalogCache(ref);
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
      await invalidateTrailCatalogCache(ref);
      return _fetch(page: currentPage);
    });
  }

  Future<PaginatedResponse<TrailSummary>> _fetch({
    required int page,
    bool force = false,
  }) async {
    final repository = ref.read(trailRepositoryProvider);
    if (repository is! TrailRepositoryImpl || !_isDefaultCatalogRequest(page)) {
      return repository.list(
        page: page,
        size: _pageSize,
        search: _search,
        premium: _premium,
        category: _category,
      );
    }

    final session = ref.read(authControllerProvider).asData?.value;
    if (session == null) {
      return repository.list(page: page, size: _pageSize);
    }
    final userId = session.userId;
    final generation = ref.read(authSessionGenerationProvider);
    final cache = await ref.read(stableResourceCacheProvider.future);
    final context = await ref.read(stableResourceCacheContextProvider.future);
    final query = const <String, Object?>{
      'page': 0,
      'size': _pageSize,
      'sortBy': 'createdAt',
      'sortDir': 'desc',
      'projection': 'summary',
    };

    bool sessionStillValid() {
      final current = ref.read(authControllerProvider).asData?.value;
      return ref.mounted &&
          current?.userId == userId &&
          ref.read(authSessionGenerationProvider) == generation;
    }

    final catalog = await cache.getOrFetch<PaginatedResponse<TrailSummary>>(
      resource: StableResource.trailCatalog,
      dio: ref.read(authenticatedDioProvider(AppConfig.contentBaseUrl)),
      path: '/v1/trails',
      queryParameters: query,
      appVersion: context.appVersion,
      locale: context.locale,
      userId: userId,
      ttl: const Duration(minutes: 30),
      maxStale: const Duration(hours: 2),
      force: force,
      extractPayload: (data) => ApiPayloadParser.dataMap(data),
      decodePayload: (payload) {
        if (payload is! Map) {
          throw const FormatException('Catalogo de trilhas invalido.');
        }
        return ApiPayloadParser.paginatedData({
          'data': Map<String, dynamic>.from(payload),
        }, (item) => TrailSummaryDto.fromJson(item).toEntity());
      },
      canWrite: sessionStillValid,
    );
    if (!sessionStillValid()) {
      throw StateError('Sessao invalida para carregar catalogo de trilhas.');
    }
    return catalog;
  }

  bool _isDefaultCatalogRequest(int page) {
    return page == 0 &&
        _search == null &&
        _premium == null &&
        _category == null;
  }

  void _resetLoadMoreState() {
    ref.read(trailCatalogLoadMoreStateProvider.notifier).reset();
  }
}
