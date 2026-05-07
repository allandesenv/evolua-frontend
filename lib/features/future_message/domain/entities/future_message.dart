class FutureMessage {
  const FutureMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.bodyPreview,
    required this.triggerType,
    required this.triggerConfig,
    required this.triggerLabel,
    required this.status,
    required this.createdContext,
    required this.deliveredContext,
    required this.createdAt,
    this.scheduledFor,
    this.deliveredAt,
    this.readAt,
    this.reaction,
  });

  final int id;
  final String? title;
  final String body;
  final String bodyPreview;
  final String triggerType;
  final Map<String, dynamic> triggerConfig;
  final String triggerLabel;
  final String status;
  final Map<String, dynamic> createdContext;
  final Map<String, dynamic> deliveredContext;
  final DateTime createdAt;
  final DateTime? scheduledFor;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String? reaction;

  bool get isDelivered => status == 'DELIVERED' || status == 'READ';
  bool get isRead => status == 'READ';
  bool get isScheduled => status == 'SCHEDULED';

  FutureMessage copyWith({
    String? status,
    DateTime? readAt,
    String? reaction,
  }) {
    return FutureMessage(
      id: id,
      title: title,
      body: body,
      bodyPreview: bodyPreview,
      triggerType: triggerType,
      triggerConfig: triggerConfig,
      triggerLabel: triggerLabel,
      status: status ?? this.status,
      createdContext: createdContext,
      deliveredContext: deliveredContext,
      createdAt: createdAt,
      scheduledFor: scheduledFor,
      deliveredAt: deliveredAt,
      readAt: readAt ?? this.readAt,
      reaction: reaction ?? this.reaction,
    );
  }
}

class FutureMessageDraft {
  const FutureMessageDraft({
    this.title,
    required this.body,
    this.promptRemember,
    this.promptFeeling,
    this.promptHope,
    required this.triggerType,
    required this.triggerConfig,
  });

  final String? title;
  final String body;
  final String? promptRemember;
  final String? promptFeeling;
  final String? promptHope;
  final String triggerType;
  final Map<String, dynamic> triggerConfig;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'promptRemember': promptRemember,
      'promptFeeling': promptFeeling,
      'promptHope': promptHope,
      'triggerType': triggerType,
      'triggerConfig': triggerConfig,
    };
  }
}
