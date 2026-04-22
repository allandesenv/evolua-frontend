import 'package:dio/dio.dart';

String extractApiErrorMessage(
  Object error, {
  String fallback = 'Nao foi possivel concluir a solicitacao.',
}) {
  if (error is DioException) {
    final data = error.response?.data;

    if (data is Map<String, dynamic>) {
      final details = data['details'];
      if (details is List && details.isNotEmpty) {
        final firstDetail = details.first?.toString().trim();
        if (firstDetail != null && firstDetail.isNotEmpty) {
          return firstDetail;
        }
      }

      final message = data['message']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    final dioMessage = error.message?.trim();
    if (dioMessage != null && dioMessage.isNotEmpty) {
      return dioMessage;
    }
  }

  final genericMessage = error.toString().trim();
  if (genericMessage.isNotEmpty) {
    return genericMessage;
  }

  return fallback;
}
