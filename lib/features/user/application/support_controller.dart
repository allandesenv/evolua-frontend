import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/cache/stable_resource_cache.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SupportConfig {
  const SupportConfig({
    required this.helpCenterUrl,
    required this.supportUrl,
    required this.professionalHelpUrl,
    required this.emotionalResourcesUrl,
    required this.aiLimitsUrl,
  });

  factory SupportConfig.fromJson(Map<String, dynamic> json) {
    return SupportConfig(
      helpCenterUrl: _optionalUrl(json['helpCenterUrl']),
      supportUrl: _optionalUrl(json['supportUrl']),
      professionalHelpUrl: _optionalUrl(json['professionalHelpUrl']),
      emotionalResourcesUrl: _optionalUrl(json['emotionalResourcesUrl']),
      aiLimitsUrl: _optionalUrl(json['aiLimitsUrl']),
    );
  }

  final Uri? helpCenterUrl;
  final Uri? supportUrl;
  final Uri? professionalHelpUrl;
  final Uri? emotionalResourcesUrl;
  final Uri? aiLimitsUrl;

  static Uri? _optionalUrl(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return Uri.tryParse(raw);
  }

  Map<String, dynamic> toJson() {
    return {
      'helpCenterUrl': helpCenterUrl?.toString(),
      'supportUrl': supportUrl?.toString(),
      'professionalHelpUrl': professionalHelpUrl?.toString(),
      'emotionalResourcesUrl': emotionalResourcesUrl?.toString(),
      'aiLimitsUrl': aiLimitsUrl?.toString(),
    };
  }
}

class SupportStatusItem {
  const SupportStatusItem({
    required this.key,
    required this.label,
    required this.state,
    required this.detail,
  });

  factory SupportStatusItem.fromJson(Map<String, dynamic> json) {
    return SupportStatusItem(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Status',
      state: json['state']?.toString() ?? 'UNKNOWN',
      detail: json['detail']?.toString() ?? 'Nao foi possivel confirmar agora.',
    );
  }

  final String key;
  final String label;
  final String state;
  final String detail;
}

class SupportTicketResult {
  const SupportTicketResult({
    required this.id,
    required this.category,
    required this.status,
    required this.createdAt,
  });

  factory SupportTicketResult.fromJson(Map<String, dynamic> json) {
    return SupportTicketResult(
      id: (json['id'] as num?)?.toInt() ?? 0,
      category: json['category']?.toString() ?? 'GENERAL',
      status: json['status']?.toString() ?? 'OPEN',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final int id;
  final String category;
  final String status;
  final DateTime createdAt;
}

class SupportRepository {
  const SupportRepository(this._dio);

  final Dio _dio;

  Future<SupportConfig> loadConfig() async {
    final response = await _dio.get<dynamic>('/v1/support/config');
    return SupportConfig.fromJson(ApiPayloadParser.dataMap(response.data));
  }

  Future<List<SupportStatusItem>> loadStatus() async {
    final response = await _dio.get<dynamic>('/v1/support/status');
    return ApiPayloadParser.dataList(
      response.data,
    ).map(SupportStatusItem.fromJson).toList();
  }

  Future<SupportTicketResult> createTicket({
    required String category,
    required String subject,
    required String message,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/support/tickets',
      data: {'category': category, 'subject': subject, 'message': message},
    );
    return SupportTicketResult.fromJson(
      ApiPayloadParser.dataMap(response.data),
    );
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(
    ref.watch(authenticatedDioProvider(AppConfig.userBaseUrl)),
  );
});

final supportConfigProvider = FutureProvider<SupportConfig>((ref) {
  return _loadCachedSupportConfig(ref);
});

final supportStatusProvider = FutureProvider<List<SupportStatusItem>>((ref) {
  return ref.watch(supportRepositoryProvider).loadStatus();
});

Future<SupportConfig> _loadCachedSupportConfig(Ref ref) async {
  final cache = await ref.read(stableResourceCacheProvider.future);
  final context = await ref.read(stableResourceCacheContextProvider.future);
  return cache.getOrFetch<SupportConfig>(
    resource: StableResource.supportConfig,
    dio: ref.read(authenticatedDioProvider(AppConfig.userBaseUrl)),
    path: '/v1/support/config',
    appVersion: context.appVersion,
    locale: context.locale,
    ttl: const Duration(hours: 6),
    maxStale: const Duration(hours: 24),
    force: false,
    extractPayload: ApiPayloadParser.dataMap,
    decodePayload: (payload) {
      if (payload is! Map) {
        throw const FormatException('Configuracao de suporte invalida.');
      }
      return SupportConfig.fromJson(Map<String, dynamic>.from(payload));
    },
  );
}
