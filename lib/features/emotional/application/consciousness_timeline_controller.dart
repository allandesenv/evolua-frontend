import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/ads/application/monetization_access_controller.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const checkInHistoryFullResource = RewardResources.checkInHistoryFull;

final consciousnessTimelineProvider =
    AsyncNotifierProvider<
      ConsciousnessTimelineController,
      ConsciousnessTimelineState
    >(ConsciousnessTimelineController.new);

final evolutionMirrorSummaryProvider = FutureProvider<EvolutionMirrorSummary>((
  ref,
) async {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.emotionalBaseUrl));
  final response = await dio.get<dynamic>('/v1/evolution-mirror/summary');
  return EvolutionMirrorSummary.fromJson(
    ApiPayloadParser.dataMap(response.data),
  );
});

class ConsciousnessTimelineState {
  const ConsciousnessTimelineState({
    required this.items,
    required this.fullAccess,
    required this.premium,
    required this.rewardedAdAvailable,
    required this.page,
    required this.size,
    required this.totalItems,
    required this.totalPages,
    required this.hasNext,
    required this.isLoadingMore,
    required this.filters,
    this.limitMessage,
  });

  final List<ConsciousnessTimelineItem> items;
  final bool fullAccess;
  final bool premium;
  final bool rewardedAdAvailable;
  final int page;
  final int size;
  final int totalItems;
  final int totalPages;
  final bool hasNext;
  final bool isLoadingMore;
  final ConsciousnessTimelineFilters filters;
  final String? limitMessage;

  ConsciousnessTimelineState copyWith({
    List<ConsciousnessTimelineItem>? items,
    bool? fullAccess,
    bool? premium,
    bool? rewardedAdAvailable,
    int? page,
    int? size,
    int? totalItems,
    int? totalPages,
    bool? hasNext,
    bool? isLoadingMore,
    ConsciousnessTimelineFilters? filters,
    String? limitMessage,
  }) {
    return ConsciousnessTimelineState(
      items: items ?? this.items,
      fullAccess: fullAccess ?? this.fullAccess,
      premium: premium ?? this.premium,
      rewardedAdAvailable: rewardedAdAvailable ?? this.rewardedAdAvailable,
      page: page ?? this.page,
      size: size ?? this.size,
      totalItems: totalItems ?? this.totalItems,
      totalPages: totalPages ?? this.totalPages,
      hasNext: hasNext ?? this.hasNext,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      filters: filters ?? this.filters,
      limitMessage: limitMessage ?? this.limitMessage,
    );
  }
}

class ConsciousnessTimelineController
    extends AsyncNotifier<ConsciousnessTimelineState> {
  static const int defaultPageSize = 20;

  @override
  Future<ConsciousnessTimelineState> build() => loadInitial();

  Future<ConsciousnessTimelineState> loadInitial({
    ConsciousnessTimelineFilters filters = const ConsciousnessTimelineFilters(),
  }) async {
    final nextState = await _fetch(
      page: 0,
      size: defaultPageSize,
      filters: filters,
    );
    state = AsyncData(nextState);
    return nextState;
  }

  Future<ConsciousnessTimelineState> load({
    String? search,
    String? mood,
    String? energyRange,
    DateTime? from,
    DateTime? to,
  }) async {
    final filters = ConsciousnessTimelineFilters(
      search: search,
      mood: mood,
      energyRange: energyRange,
      from: from,
      to: to,
    );
    return loadInitial(filters: filters);
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null ||
        current.isLoadingMore ||
        !current.hasNext ||
        state.isLoading) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await _fetch(
        page: current.page + 1,
        size: current.size,
        filters: current.filters,
      );
      state = AsyncData(
        next.copyWith(
          items: [...current.items, ...next.items],
          isLoadingMore: false,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> applyFilters(ConsciousnessTimelineFilters filters) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => loadInitial(filters: filters));
  }

  Future<void> clearFilters() =>
      applyFilters(const ConsciousnessTimelineFilters());

  Future<bool> unlockFullWithReward() async {
    final filters =
        state.asData?.value.filters ?? const ConsciousnessTimelineFilters();
    final controller = ref.read(monetizationAccessControllerProvider.notifier);
    final result = await controller.unlockWithRewardedAdResult(
      resource: checkInHistoryFullResource,
    );
    debugPrint('Evolua timeline full unlock reward result=${result.name}');

    if (result == RewardedAdResult.rewarded) {
      final refreshed = await loadInitial(filters: filters);
      return refreshed.fullAccess;
    }

    return false;
  }

  Future<void> refreshFull() async {
    final filters =
        state.asData?.value.filters ?? const ConsciousnessTimelineFilters();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => loadInitial(filters: filters));
  }

  Future<ConsciousnessTimelineState> _fetch({
    required int page,
    required int size,
    required ConsciousnessTimelineFilters filters,
  }) async {
    final dio = ref.read(authenticatedDioProvider(AppConfig.emotionalBaseUrl));
    final response = await dio.get<dynamic>(
      '/v1/check-ins/consciousness-timeline',
      queryParameters: {
        'page': page,
        'size': size,
        if ((filters.search ?? '').trim().isNotEmpty)
          'search': filters.search!.trim(),
        if ((filters.mood ?? '').trim().isNotEmpty)
          'mood': filters.mood!.trim(),
        if ((filters.energyRange ?? '').trim().isNotEmpty)
          'energyRange': filters.energyRange!.trim(),
        if (filters.from != null) 'from': _formatDate(filters.from!),
        if (filters.to != null) 'to': _formatDate(filters.to!),
      },
    );
    final data = ApiPayloadParser.dataMap(response.data);
    return ConsciousnessTimelineState(
      items: (data['items'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => ConsciousnessTimelineItem.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
      fullAccess: data['fullAccess'] as bool? ?? false,
      premium: data['premium'] as bool? ?? false,
      rewardedAdAvailable: data['rewardedAdAvailable'] as bool? ?? false,
      page: (data['page'] as num?)?.toInt() ?? page,
      size: (data['size'] as num?)?.toInt() ?? size,
      totalItems: (data['totalItems'] as num?)?.toInt() ?? 0,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
      hasNext: data['hasNext'] as bool? ?? false,
      isLoadingMore: false,
      filters: filters,
      limitMessage: data['limitMessage']?.toString(),
    );
  }

  String _formatDate(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }
}

class ConsciousnessTimelineFilters {
  const ConsciousnessTimelineFilters({
    this.search,
    this.mood,
    this.energyRange,
    this.from,
    this.to,
  });

  final String? search;
  final String? mood;
  final String? energyRange;
  final DateTime? from;
  final DateTime? to;

  bool get isEmpty =>
      (search ?? '').trim().isEmpty &&
      (mood ?? '').trim().isEmpty &&
      (energyRange ?? '').trim().isEmpty &&
      from == null &&
      to == null;
}

class ConsciousnessTimelineItem {
  const ConsciousnessTimelineItem({
    required this.checkInId,
    required this.mood,
    required this.energyLevel,
    required this.title,
    required this.insight,
    required this.identifiedState,
    required this.revealingQuestion,
    required this.possibleNewState,
    required this.microAction,
    required this.reflection,
    required this.savedReading,
    required this.createdAt,
  });

  final int checkInId;
  final String mood;
  final int? energyLevel;
  final String title;
  final String insight;
  final String identifiedState;
  final String revealingQuestion;
  final String possibleNewState;
  final String microAction;
  final String reflection;
  final bool savedReading;
  final DateTime? createdAt;

  factory ConsciousnessTimelineItem.fromJson(Map<String, dynamic> json) {
    return ConsciousnessTimelineItem(
      checkInId: (json['checkInId'] as num?)?.toInt() ?? 0,
      mood: json['mood']?.toString() ?? '',
      energyLevel: (json['energyLevel'] as num?)?.toInt(),
      title: json['title']?.toString() ?? '',
      insight: json['insight']?.toString() ?? '',
      identifiedState: json['identifiedState']?.toString() ?? '',
      revealingQuestion: json['revealingQuestion']?.toString() ?? '',
      possibleNewState: json['possibleNewState']?.toString() ?? '',
      microAction: json['microAction']?.toString() ?? '',
      reflection: json['reflection']?.toString() ?? '',
      savedReading: json['savedReading'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

class EvolutionMirrorSummary {
  const EvolutionMirrorSummary({
    required this.checkInCount,
    required this.averageEnergy,
    required this.energyTrend,
    required this.dominantMood,
    required this.recurringStates,
    required this.emotionalThemes,
    required this.revealingQuestions,
    required this.microActions,
    required this.progressSignal,
    required this.disclaimer,
  });

  final int checkInCount;
  final double? averageEnergy;
  final String energyTrend;
  final String dominantMood;
  final List<CountInsight> recurringStates;
  final List<CountInsight> emotionalThemes;
  final List<String> revealingQuestions;
  final List<String> microActions;
  final String progressSignal;
  final String disclaimer;

  factory EvolutionMirrorSummary.fromJson(Map<String, dynamic> json) {
    return EvolutionMirrorSummary(
      checkInCount: (json['checkInCount'] as num?)?.toInt() ?? 0,
      averageEnergy: (json['averageEnergy'] as num?)?.toDouble(),
      energyTrend: json['energyTrend']?.toString() ?? '',
      dominantMood: json['dominantMood']?.toString() ?? '',
      recurringStates: _countList(json['recurringStates']),
      emotionalThemes: _countList(json['emotionalThemes']),
      revealingQuestions: _stringList(json['revealingQuestions']),
      microActions: _stringList(json['microActions']),
      progressSignal: json['progressSignal']?.toString() ?? '',
      disclaimer: json['disclaimer']?.toString() ?? '',
    );
  }
}

class CountInsight {
  const CountInsight({required this.label, required this.count});

  final String label;
  final int count;
}

List<CountInsight> _countList(dynamic value) {
  return (value as List? ?? const [])
      .whereType<Map>()
      .map((item) {
        final map = Map<String, dynamic>.from(item);
        return CountInsight(
          label: map['label']?.toString() ?? '',
          count: (map['count'] as num?)?.toInt() ?? 0,
        );
      })
      .where((item) => item.label.trim().isNotEmpty)
      .toList(growable: false);
}

List<String> _stringList(dynamic value) {
  return (value as List? ?? const [])
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
