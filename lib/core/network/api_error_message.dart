import 'package:dio/dio.dart';
import 'package:evolua_frontend/l10n/generated/app_localizations.dart';

enum FriendlyApiErrorType {
  noInternet,
  timeout,
  sessionExpired,
  paymentRequired,
  serverUnavailable,
  unknown,
}

FriendlyApiErrorType classifyApiError(Object? error) {
  if (error is DioException) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return FriendlyApiErrorType.timeout;
    }

    if (error.type == DioExceptionType.connectionError) {
      return FriendlyApiErrorType.noInternet;
    }

    final statusCode = error.response?.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      return FriendlyApiErrorType.sessionExpired;
    }
    if (statusCode == 402) {
      return FriendlyApiErrorType.paymentRequired;
    }
    if (statusCode != null && statusCode >= 500) {
      return FriendlyApiErrorType.serverUnavailable;
    }
  }

  return FriendlyApiErrorType.unknown;
}

String friendlyApiErrorMessage(
  Object? error,
  AppLocalizations l10n, {
  String? fallback,
}) {
  switch (classifyApiError(error)) {
    case FriendlyApiErrorType.noInternet:
      return l10n.errorNoInternet;
    case FriendlyApiErrorType.timeout:
      return l10n.errorTimeout;
    case FriendlyApiErrorType.sessionExpired:
      return l10n.errorSessionExpired;
    case FriendlyApiErrorType.paymentRequired:
      return extractApiErrorMessage(
        error ?? Object(),
        fallback: l10n.errorCheckInQuota,
      );
    case FriendlyApiErrorType.serverUnavailable:
      return l10n.errorServerUnavailable;
    case FriendlyApiErrorType.unknown:
      return extractApiErrorMessage(
        error ?? Object(),
        fallback: fallback ?? l10n.errorUnexpected,
      );
  }
}

String extractApiErrorMessage(
  Object error, {
  String fallback = 'Não foi possível concluir a solicitação.',
}) {
  if (error is DioException) {
    switch (classifyApiError(error)) {
      case FriendlyApiErrorType.noInternet:
        return 'Não conseguimos conectar agora. Verifique sua internet e tente novamente.';
      case FriendlyApiErrorType.timeout:
        return 'A resposta demorou mais que o esperado. Tente novamente em instantes.';
      case FriendlyApiErrorType.sessionExpired:
        return 'Sua sessão expirou. Entre novamente para continuar.';
      case FriendlyApiErrorType.serverUnavailable:
        return 'O Evolua está temporariamente indisponível. Tente novamente em alguns instantes.';
      case FriendlyApiErrorType.paymentRequired:
      case FriendlyApiErrorType.unknown:
        break;
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
  return lower.contains('401') ||
      lower.contains('403') ||
      lower.contains('500') ||
      lower.contains('forbidden') ||
      lower.contains('unauthorized') ||
      lower.contains('stacktrace') ||
      lower.contains('stack trace') ||
      lower.contains('exception') ||
      lower.contains('dioexception') ||
      lower.contains('httpexception') ||
      lower.contains('socketexception') ||
      lower.contains('java.') ||
      lower.contains('org.springframework');
}
