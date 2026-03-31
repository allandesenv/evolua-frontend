import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';

class SubscriptionRecordDto {
  const SubscriptionRecordDto({
    required this.id,
    required this.userId,
    required this.planCode,
    required this.status,
    required this.billingCycle,
    required this.premium,
    required this.createdAt,
  });

  final int id;
  final String userId;
  final String planCode;
  final String status;
  final String billingCycle;
  final bool premium;
  final DateTime createdAt;

  factory SubscriptionRecordDto.fromJson(Map<String, dynamic> json) {
    return SubscriptionRecordDto(
      id: (json['id'] as num).toInt(),
      userId: json['userId'].toString(),
      planCode: json['planCode'].toString(),
      status: json['status'].toString(),
      billingCycle: json['billingCycle'].toString(),
      premium: json['premium'] as bool,
      createdAt: DateTime.parse(json['createdAt'].toString()),
    );
  }

  SubscriptionRecord toEntity() {
    return SubscriptionRecord(
      id: id,
      userId: userId,
      planCode: planCode,
      status: status,
      billingCycle: billingCycle,
      premium: premium,
      createdAt: createdAt,
    );
  }
}
