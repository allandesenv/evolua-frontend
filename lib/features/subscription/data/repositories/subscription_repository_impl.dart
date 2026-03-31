import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/features/subscription/data/models/subscription_record_dto.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  const SubscriptionRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<SubscriptionRecord>> list() async {
    final response = await _dio.get<dynamic>('/v1/subscriptions');

    return ApiPayloadParser.dataList(response.data)
        .map(SubscriptionRecordDto.fromJson)
        .map((item) => item.toEntity())
        .toList();
  }

  @override
  Future<SubscriptionRecord> create({
    required String planCode,
    required String status,
    required String billingCycle,
    required bool premium,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/subscriptions',
      data: {
        'planCode': planCode,
        'status': status,
        'billingCycle': billingCycle,
        'premium': premium,
      },
    );

    return SubscriptionRecordDto.fromJson(ApiPayloadParser.dataMap(response.data)).toEntity();
  }
}
