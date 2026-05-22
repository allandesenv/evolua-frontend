import 'package:dio/dio.dart';

String extractApiErrorMessage(
  Object error, {
  String fallback = 'Nao foi possivel concluir a solicitacao.',
}) {
  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      return fallback;
    }

    final data = error.response?.data;

    if (data is Map<String, dynamic>) {
      final details = data['details'];
      if (details is List && details.isNotEmpty) {
        final firstDetail = details.first?.toString().trim();
        if (firstDetail != null &&
            firstDetail.isNotEmpty &&
            !_isTechnicalMessage(firstDetail)) {
          return firstDetail;
        }
      }

      final message = data['message']?.toString().trim();
      if (message != null &&
          message.isNotEmpty &&
          !_isTechnicalMessage(message)) {
        return message;
      }
    }

    final dioMessage = error.message?.trim();
    if (dioMessage != null &&
        dioMessage.isNotEmpty &&
        !_isTechnicalMessage(dioMessage)) {
      return dioMessage;
    }
  }

  final genericMessage = error.toString().trim();
  if (genericMessage.isNotEmpty && !_isTechnicalMessage(genericMessage)) {
    return genericMessage;
  }

  return fallback;
}

bool _isTechnicalMessage(String message) {
  final lower = message.toLowerCase();
  return lower.contains('403') ||
      lower.contains('forbidden') ||
      lower.contains('stacktrace') ||
      lower.contains('stack trace') ||
      lower.contains('exception') ||
      lower.contains('dioexception') ||
      lower.contains('httpexception') ||
      lower.contains('java.') ||
      lower.contains('org.springframework');
}
