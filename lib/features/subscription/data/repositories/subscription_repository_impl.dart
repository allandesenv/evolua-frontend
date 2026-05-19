import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  const SubscriptionRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<PlanView>> listPlans() async {
    final response = await _dio.get<dynamic>('/v1/plans');
    return ApiPayloadParser.dataList(response.data)
        .map(
          (json) => PlanView(
            planCode: json['planCode'].toString(),
            title: json['title'].toString(),
            subtitle: json['subtitle'].toString(),
            billingCycle: json['billingCycle'].toString(),
            premium: json['premium'] as bool? ?? false,
            price: (json['price'] as num?)?.toDouble() ?? 0,
            currency: json['currency']?.toString() ?? 'BRL',
            benefits: (json['benefits'] as List? ?? const [])
                .map((item) => item.toString())
                .toList(),
            active: json['active'] as bool? ?? true,
            planFamily: json['planFamily']?.toString() ?? 'STANDARD',
            badge: json['badge']?.toString(),
            highlighted: json['highlighted'] as bool? ?? false,
            availabilityNote: json['availabilityNote']?.toString(),
            providerProductId: json['providerProductId']?.toString(),
            sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }

  @override
  Future<CurrentSubscription?> current() async {
    final response = await _dio.get<dynamic>('/v1/subscription/current');
    final responseMap = response.data;
    if (responseMap is! Map<String, dynamic>) {
      return null;
    }
    final payload = responseMap['data'];
    if (payload is! Map<String, dynamic>) {
      return null;
    }
    return _currentFromJson(payload);
  }

  @override
  Future<CheckoutSession> startCheckout({
    required String planCode,
    required String frontendBaseUrl,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/billing/checkout',
      data: {'planCode': planCode, 'frontendBaseUrl': frontendBaseUrl},
    );
    return _checkoutFromJson(ApiPayloadParser.dataMap(response.data));
  }

  @override
  Future<CheckoutSession> checkoutStatus(String checkoutId) async {
    final response = await _dio.get<dynamic>(
      '/v1/billing/checkout/$checkoutId',
    );
    return _checkoutFromJson(ApiPayloadParser.dataMap(response.data));
  }

  @override
  Future<CurrentSubscription?> cancel() async {
    final response = await _dio.post<dynamic>('/v1/subscription/cancel');
    return _currentFromJson(ApiPayloadParser.dataMap(response.data));
  }

  @override
  Future<AdRewardSession> createRewardSession({
    required String rewardType,
    String? contextId,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/ads/reward-session',
      data: {
        'rewardType': rewardType,
        if (contextId != null && contextId.trim().isNotEmpty)
          'contextId': contextId.trim(),
      },
    );
    final json = ApiPayloadParser.dataMap(response.data);
    return AdRewardSession(
      id: json['id']?.toString() ?? '',
      provider: json['provider']?.toString() ?? 'ADMOB',
      rewardType: json['rewardType']?.toString() ?? rewardType,
      contextId: json['contextId']?.toString(),
      status: json['status']?.toString() ?? 'CREATED',
      customData:
          json['customData']?.toString() ?? json['id']?.toString() ?? '',
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.now().add(const Duration(minutes: 15)),
      grantedAt: json['grantedAt'] == null
          ? null
          : DateTime.tryParse(json['grantedAt'].toString()),
    );
  }

  @override
  Future<MonetizationAccessStatus> monetizationAccess({
    required String resource,
    String? contextId,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/monetization/access',
      queryParameters: {
        'resource': resource,
        if (contextId != null && contextId.trim().isNotEmpty)
          'contextId': contextId.trim(),
      },
    );
    final json = ApiPayloadParser.dataMap(response.data);
    return MonetizationAccessStatus(
      resource: json['resource']?.toString() ?? resource,
      contextId: json['contextId']?.toString(),
      allowed: json['allowed'] as bool? ?? false,
      premium: json['premium'] as bool? ?? false,
      rewardedAdAvailable: json['rewardedAdAvailable'] as bool? ?? false,
      upgradeRecommended: json['upgradeRecommended'] as bool? ?? true,
      limitMessage: json['limitMessage']?.toString(),
      entitlementExpiresAt: json['entitlementExpiresAt'] == null
          ? null
          : DateTime.tryParse(json['entitlementExpiresAt'].toString()),
    );
  }

  CurrentSubscription? _currentFromJson(Map<String, dynamic> json) {
    if (json.isEmpty) {
      return null;
    }
    return CurrentSubscription(
      planCode: json['planCode']?.toString() ?? 'essential-free',
      status: json['status']?.toString() ?? 'NONE',
      billingCycle: json['billingCycle']?.toString() ?? 'MONTHLY',
      premium: json['premium'] as bool? ?? false,
      adsEnabled: json['adsEnabled'] as bool? ?? true,
      aiQuotaRemainingToday:
          (json['aiQuotaRemainingToday'] as num?)?.toInt() ?? 0,
      mentorPremiumPassActive:
          json['mentorPremiumPassActive'] as bool? ?? false,
      mentorRewardedAdAvailable:
          json['mentorRewardedAdAvailable'] as bool? ?? false,
      provider: json['provider']?.toString(),
      mentorPremiumPassEndsAt: json['mentorPremiumPassEndsAt'] == null
          ? null
          : DateTime.tryParse(json['mentorPremiumPassEndsAt'].toString()),
      currentPeriodEndsAt: json['currentPeriodEndsAt'] == null
          ? null
          : DateTime.tryParse(json['currentPeriodEndsAt'].toString()),
      canceledAt: json['canceledAt'] == null
          ? null
          : DateTime.tryParse(json['canceledAt'].toString()),
    );
  }

  CheckoutSession _checkoutFromJson(Map<String, dynamic> json) {
    return CheckoutSession(
      id: json['id'].toString(),
      planCode: json['planCode'].toString(),
      billingCycle: json['billingCycle'].toString(),
      status: json['status'].toString(),
      premium: json['premium'] as bool? ?? false,
      checkoutUrl: json['checkoutUrl']?.toString(),
      failureReason: json['failureReason']?.toString(),
      confirmedAt: json['confirmedAt'] == null
          ? null
          : DateTime.tryParse(json['confirmedAt'].toString()),
    );
  }
}
