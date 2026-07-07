import 'package:evolua_frontend/features/future_message/domain/entities/future_message.dart';

const _supportedAfterDays = {7, 30};

String futureMessageDeliveryLabel(FutureMessage message) {
  final triggerType = message.triggerType.trim().toUpperCase();

  if (triggerType == 'SPECIFIC_DATE') {
    final date = _localDateFromConfig(message.triggerConfig['date']);
    if (date != null) {
      return 'Entrega em ${_formatDate(date)}';
    }
  }

  if (triggerType == 'AFTER_DAYS') {
    final days = _supportedDays(message.triggerConfig['days']);
    if (days != null) {
      return 'Entrega em $days dias';
    }
  }

  final eventLabel = _eventTriggerLabel(triggerType);
  if (eventLabel != null) {
    return eventLabel;
  }

  final scheduledFor = message.scheduledFor;
  if (scheduledFor != null) {
    return 'Entrega em ${_formatDate(scheduledFor.toLocal())}';
  }

  final storedLabel = message.triggerLabel.trim();
  if (storedLabel.isNotEmpty && !_isInternalLabel(storedLabel)) {
    return storedLabel;
  }

  return 'Entrega programada';
}

DateTime? _localDateFromConfig(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  final parts = text.split('-');
  if (parts.length != 3) {
    return null;
  }
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return null;
  }
  try {
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  } catch (_) {
    return null;
  }
}

int? _supportedDays(Object? value) {
  final days = value is num ? value.toInt() : int.tryParse('$value');
  if (days == null || !_supportedAfterDays.contains(days)) {
    return null;
  }
  return days;
}

String? _eventTriggerLabel(String triggerType) {
  return switch (triggerType) {
    'LOW_ENERGY_CHECKIN' => 'Quando eu estiver desanimado',
    'BAD_DAY_STREAK' => 'Quando houver dias dificeis em sequencia',
    'HIGH_ANXIETY' => 'Quando a ansiedade estiver alta',
    'INACTIVITY_AFTER_DAYS' => 'Quando eu parar de usar o app',
    'RETURN_AFTER_DAYS' => 'Quando eu voltar depois de dias',
    'TRAIL_COMPLETED' => 'Quando eu concluir uma trilha',
    'MOOD_IMPROVED' => 'Quando meu humor melhorar',
    'PATTERN_CHANGED' => 'Quando um padrao mudar',
    _ => null,
  };
}

bool _isInternalLabel(String value) {
  final text = value.trim();
  return RegExp(r'^[A-Z0-9_]+$').hasMatch(text);
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}
