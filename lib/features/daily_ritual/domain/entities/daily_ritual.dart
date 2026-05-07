class DailyRitual {
  const DailyRitual({
    required this.id,
    required this.localDate,
    required this.type,
    required this.emotionalState,
    required this.dayNeed,
    required this.intention,
    required this.microAction,
    required this.createdAt,
  });

  final int id;
  final DateTime localDate;
  final String type;
  final String emotionalState;
  final String dayNeed;
  final String intention;
  final String microAction;
  final DateTime createdAt;

  bool get isMorning => type == DailyRitualType.morning;
  bool get isEvening => type == DailyRitualType.evening;
}

class DailyRitualDraft {
  const DailyRitualDraft({
    required this.localDate,
    required this.type,
    required this.emotionalState,
    required this.dayNeed,
    required this.intention,
    required this.microAction,
  });

  final DateTime localDate;
  final String type;
  final String emotionalState;
  final String dayNeed;
  final String intention;
  final String microAction;

  Map<String, dynamic> toJson() {
    return {
      'localDate': _formatDate(localDate),
      'type': type,
      'emotionalState': emotionalState,
      'dayNeed': dayNeed,
      'intention': intention,
      'microAction': microAction,
    };
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

class DailyRitualType {
  const DailyRitualType._();

  static const morning = 'MORNING';
  static const evening = 'EVENING';

  static String fromRouteValue(String? value) {
    return value?.toLowerCase() == 'evening' ? evening : morning;
  }

  static String toRouteValue(String type) {
    return type == evening ? 'evening' : 'morning';
  }
}
