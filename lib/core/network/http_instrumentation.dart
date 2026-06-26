import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const httpInstrumentationRetryExtraKey = 'evolua.http.retry';
const httpInstrumentationOriginExtraKey = 'evolua.http.origin';
const httpInstrumentationRouteTemplateExtraKey = 'evolua.http.routeTemplate';
const httpInstrumentationLogicalRequestIdExtraKey =
    'evolua.http.logicalRequestId';

const _attemptStopwatchExtraKey = 'evolua.http.instrumentation.stopwatch';

const _releaseInstrumentationEnabled = bool.fromEnvironment(
  'EVOLUA_HTTP_INSTRUMENTATION_ENABLED',
);

final httpInstrumentationRecorderProvider =
    Provider<HttpInstrumentationRecorder>((ref) {
      return defaultHttpInstrumentationRecorder();
    });

HttpInstrumentationRecorder defaultHttpInstrumentationRecorder({
  bool releaseMode = kReleaseMode,
  bool releaseEnabled = _releaseInstrumentationEnabled,
}) {
  final mode = HttpInstrumentationMode.fromEnvironment(
    releaseMode: releaseMode,
    releaseEnabled: releaseEnabled,
  );
  return switch (mode) {
    HttpInstrumentationMode.noop => const NoOpHttpInstrumentationRecorder(),
    HttpInstrumentationMode.aggregateOnly => LimitedHttpInstrumentationRecorder(
      keepDetailedEvents: false,
    ),
    HttpInstrumentationMode.detailed => LimitedHttpInstrumentationRecorder(
      keepDetailedEvents: true,
    ),
  };
}

void attachHttpInstrumentation(
  Dio dio, {
  required HttpInstrumentationRecorder recorder,
}) {
  if (dio.interceptors.any(
    (interceptor) => interceptor is HttpInstrumentationInterceptor,
  )) {
    return;
  }

  dio.interceptors.add(HttpInstrumentationInterceptor(recorder));
}

enum HttpInstrumentationMode {
  noop,
  aggregateOnly,
  detailed;

  static HttpInstrumentationMode fromEnvironment({
    required bool releaseMode,
    required bool releaseEnabled,
  }) {
    if (releaseMode) {
      return releaseEnabled ? aggregateOnly : noop;
    }
    return detailed;
  }
}

enum HttpInstrumentationOrigin {
  startup('startup'),
  home('home'),
  auth('auth'),
  appUpdate('app_update'),
  careClaim('care_claim'),
  manualRefresh('manual_refresh'),
  pagination('pagination'),
  rewardPolling('reward_polling'),
  checkoutPolling('checkout_polling'),
  backgroundRefresh('background_refresh'),
  unspecified('unspecified');

  const HttpInstrumentationOrigin(this.value);

  final String value;
}

String sanitizedHttpInstrumentationOrigin(Object? value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return HttpInstrumentationOrigin.unspecified.value;
  }
  for (final origin in HttpInstrumentationOrigin.values) {
    if (origin.value == raw) {
      return origin.value;
    }
  }
  return HttpInstrumentationOrigin.unspecified.value;
}

String normalizeHttpMetricRoute(RequestOptions request) {
  final template = request.extra[httpInstrumentationRouteTemplateExtraKey];
  if (template is String) {
    final normalizedTemplate = _normalizeRouteTemplate(template);
    if (normalizedTemplate != null) {
      return normalizedTemplate;
    }
  }
  return normalizeHttpMetricPath(request.path);
}

String normalizeHttpMetricPath(String rawPath) {
  final uri = Uri.tryParse(rawPath);
  final path = uri == null
      ? rawPath.split('?').first
      : (uri.hasAbsolutePath ? uri.path : uri.path);
  final safePath = path.trim().isEmpty ? '/' : path.trim();
  final segments = safePath
      .split('/')
      .where((segment) => segment.trim().isNotEmpty)
      .toList(growable: false);
  if (segments.isEmpty) {
    return '/';
  }

  final normalized = <String>[];
  for (var index = 0; index < segments.length; index++) {
    final segment = segments[index];
    final previous = index == 0 ? '' : segments[index - 1].toLowerCase();
    final current = segment.toLowerCase();

    if (current == 'v1') {
      normalized.add(segment);
    } else if (_isKnownOpaqueIdentifier(previous: previous, current: current)) {
      normalized.add(_placeholderFor(previous));
    } else if (_numericIdPattern.hasMatch(segment)) {
      normalized.add('{id}');
    } else if (_uuidPattern.hasMatch(segment)) {
      normalized.add('{uuid}');
    } else {
      normalized.add(segment);
    }
  }

  return '/${normalized.join('/')}';
}

String? _normalizeRouteTemplate(String value) {
  final path = value.split('?').first.trim();
  if (path.isEmpty ||
      !path.startsWith('/') ||
      path.contains(RegExp(r'\s')) ||
      path.length > 240) {
    return null;
  }
  return normalizeHttpMetricPath(path);
}

bool _isKnownOpaqueIdentifier({
  required String previous,
  required String current,
}) {
  if (current.isEmpty || current.startsWith('{')) {
    return false;
  }
  return switch (previous) {
    'checkout' || 'checkouts' => true,
    'reward-session' || 'reward-sessions' => true,
    _ => false,
  };
}

String _placeholderFor(String previous) {
  return switch (previous) {
    'checkout' || 'checkouts' => '{checkoutId}',
    'reward-session' || 'reward-sessions' => '{rewardSessionId}',
    _ => '{id}',
  };
}

final _numericIdPattern = RegExp(r'^\d+$');
final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

abstract class HttpInstrumentationRecorder {
  const HttpInstrumentationRecorder();

  void recordLogicalRequest(RequestOptions request);

  void recordRefreshRequest(RequestOptions request);

  void recordAttempt(HttpInstrumentationEvent event);

  HttpInstrumentationSnapshot snapshot();

  void reset();
}

class NoOpHttpInstrumentationRecorder extends HttpInstrumentationRecorder {
  const NoOpHttpInstrumentationRecorder();

  @override
  void recordAttempt(HttpInstrumentationEvent event) {}

  @override
  void recordLogicalRequest(RequestOptions request) {}

  @override
  void recordRefreshRequest(RequestOptions request) {}

  @override
  void reset() {}

  @override
  HttpInstrumentationSnapshot snapshot() {
    return const HttpInstrumentationSnapshot(
      logicalRequests: 0,
      httpAttempts: 0,
      retries: 0,
      refreshRequests: 0,
      errors: 0,
      cancellations: 0,
      timeouts: 0,
      totalDuration: Duration.zero,
      knownResponseBytes: 0,
      routes: {},
      recentEvents: [],
    );
  }
}

class LimitedHttpInstrumentationRecorder extends HttpInstrumentationRecorder {
  LimitedHttpInstrumentationRecorder({
    required bool keepDetailedEvents,
    this.maxRecentEvents = 500,
  }) : _keepDetailedEvents = keepDetailedEvents;

  final bool _keepDetailedEvents;
  final int maxRecentEvents;
  final _routes = <String, HttpRouteMetric>{};
  final _recentEvents = Queue<HttpInstrumentationEvent>();

  int _logicalRequests = 0;
  int _httpAttempts = 0;
  int _retries = 0;
  int _refreshRequests = 0;
  int _errors = 0;
  int _cancellations = 0;
  int _timeouts = 0;
  Duration _totalDuration = Duration.zero;
  int _knownResponseBytes = 0;

  @override
  void recordAttempt(HttpInstrumentationEvent event) {
    _httpAttempts++;
    if (event.isRetry) {
      _retries++;
    }
    if (event.isCancellation) {
      _cancellations++;
    } else if (event.isTimeout) {
      _timeouts++;
    } else if (event.isError) {
      _errors++;
    }
    _totalDuration += event.duration;
    final responseBytes = event.responseBytes;
    if (responseBytes != null) {
      _knownResponseBytes += responseBytes;
    }

    final routeKey = '${event.method} ${event.normalizedRoute}';
    _routes.update(
      routeKey,
      (metric) => metric.add(event),
      ifAbsent: () => HttpRouteMetric.fromEvent(event),
    );

    if (_keepDetailedEvents) {
      _recentEvents.addLast(event);
      while (_recentEvents.length > maxRecentEvents) {
        _recentEvents.removeFirst();
      }
    }
  }

  @override
  void recordLogicalRequest(RequestOptions request) {
    if (!_isRefreshRequest(request)) {
      _logicalRequests++;
    }
  }

  @override
  void recordRefreshRequest(RequestOptions request) {
    if (_isRefreshRequest(request)) {
      _refreshRequests++;
    }
  }

  @override
  void reset() {
    _logicalRequests = 0;
    _httpAttempts = 0;
    _retries = 0;
    _refreshRequests = 0;
    _errors = 0;
    _cancellations = 0;
    _timeouts = 0;
    _totalDuration = Duration.zero;
    _knownResponseBytes = 0;
    _routes.clear();
    _recentEvents.clear();
  }

  @override
  HttpInstrumentationSnapshot snapshot() {
    return HttpInstrumentationSnapshot(
      logicalRequests: _logicalRequests,
      httpAttempts: _httpAttempts,
      retries: _retries,
      refreshRequests: _refreshRequests,
      errors: _errors,
      cancellations: _cancellations,
      timeouts: _timeouts,
      totalDuration: _totalDuration,
      knownResponseBytes: _knownResponseBytes,
      routes: Map.unmodifiable(_routes),
      recentEvents: List.unmodifiable(_recentEvents),
    );
  }
}

class HttpInstrumentationInterceptor extends Interceptor {
  HttpInstrumentationInterceptor(this._recorder);

  final HttpInstrumentationRecorder _recorder;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_attemptStopwatchExtraKey] = Stopwatch()..start();
    final isRetry = options.extra[httpInstrumentationRetryExtraKey] == true;
    if (!isRetry) {
      _recorder.recordLogicalRequest(options);
    }
    _recorder.recordRefreshRequest(options);
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _recordResponse(response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response != null) {
      _recordResponse(response, error: err);
    } else {
      _recorder.recordAttempt(_eventForError(err));
    }
    handler.next(err);
  }

  void _recordResponse(Response<dynamic> response, {DioException? error}) {
    final request = response.requestOptions;
    _recorder.recordAttempt(
      HttpInstrumentationEvent(
        method: request.method.toUpperCase(),
        normalizedRoute: normalizeHttpMetricRoute(request),
        statusCode: response.statusCode,
        duration: _stopwatchDuration(request),
        responseBytes: approximateResponseBytes(response),
        isRetry: request.extra[httpInstrumentationRetryExtraKey] == true,
        origin: sanitizedHttpInstrumentationOrigin(
          request.extra[httpInstrumentationOriginExtraKey],
        ),
        errorType: error?.type,
      ),
    );
  }

  HttpInstrumentationEvent _eventForError(DioException error) {
    final request = error.requestOptions;
    return HttpInstrumentationEvent(
      method: request.method.toUpperCase(),
      normalizedRoute: normalizeHttpMetricRoute(request),
      statusCode: null,
      duration: _stopwatchDuration(request),
      responseBytes: null,
      isRetry: request.extra[httpInstrumentationRetryExtraKey] == true,
      origin: sanitizedHttpInstrumentationOrigin(
        request.extra[httpInstrumentationOriginExtraKey],
      ),
      errorType: error.type,
    );
  }

  Duration _stopwatchDuration(RequestOptions request) {
    final value = request.extra[_attemptStopwatchExtraKey];
    if (value is Stopwatch) {
      value.stop();
      return value.elapsed;
    }
    return Duration.zero;
  }
}

int? approximateResponseBytes(Response<dynamic> response) {
  final contentLength = response.headers.value(Headers.contentLengthHeader);
  final parsedContentLength = int.tryParse(contentLength ?? '');
  if (parsedContentLength != null && parsedContentLength >= 0) {
    return parsedContentLength;
  }

  final data = response.data;
  if (data is Uint8List) {
    return data.lengthInBytes;
  }
  if (data is List<int>) {
    return data.length;
  }
  return null;
}

bool _isRefreshRequest(RequestOptions request) {
  return normalizeHttpMetricPath(request.path) == '/v1/public/auth/refresh';
}

class HttpInstrumentationEvent {
  const HttpInstrumentationEvent({
    required this.method,
    required this.normalizedRoute,
    required this.statusCode,
    required this.duration,
    required this.responseBytes,
    required this.isRetry,
    required this.origin,
    this.errorType,
  });

  final String method;
  final String normalizedRoute;
  final int? statusCode;
  final Duration duration;
  final int? responseBytes;
  final bool isRetry;
  final String origin;
  final DioExceptionType? errorType;

  bool get isCancellation => errorType == DioExceptionType.cancel;

  bool get isTimeout {
    return errorType == DioExceptionType.connectionTimeout ||
        errorType == DioExceptionType.sendTimeout ||
        errorType == DioExceptionType.receiveTimeout;
  }

  bool get isError {
    return errorType != null ||
        statusCode == null ||
        (statusCode != null && statusCode! >= 400);
  }
}

class HttpRouteMetric {
  const HttpRouteMetric({
    required this.method,
    required this.normalizedRoute,
    required this.attempts,
    required this.retries,
    required this.errors,
    required this.cancellations,
    required this.timeouts,
    required this.totalDuration,
    required this.knownResponseBytes,
  });

  factory HttpRouteMetric.fromEvent(HttpInstrumentationEvent event) {
    return const HttpRouteMetric(
      method: '',
      normalizedRoute: '',
      attempts: 0,
      retries: 0,
      errors: 0,
      cancellations: 0,
      timeouts: 0,
      totalDuration: Duration.zero,
      knownResponseBytes: 0,
    ).add(event);
  }

  final String method;
  final String normalizedRoute;
  final int attempts;
  final int retries;
  final int errors;
  final int cancellations;
  final int timeouts;
  final Duration totalDuration;
  final int knownResponseBytes;

  HttpRouteMetric add(HttpInstrumentationEvent event) {
    return HttpRouteMetric(
      method: event.method,
      normalizedRoute: event.normalizedRoute,
      attempts: attempts + 1,
      retries: retries + (event.isRetry ? 1 : 0),
      errors: errors + (event.isError ? 1 : 0),
      cancellations: cancellations + (event.isCancellation ? 1 : 0),
      timeouts: timeouts + (event.isTimeout ? 1 : 0),
      totalDuration: totalDuration + event.duration,
      knownResponseBytes: knownResponseBytes + (event.responseBytes ?? 0),
    );
  }
}

class HttpInstrumentationSnapshot {
  const HttpInstrumentationSnapshot({
    required this.logicalRequests,
    required this.httpAttempts,
    required this.retries,
    required this.refreshRequests,
    required this.errors,
    required this.cancellations,
    required this.timeouts,
    required this.totalDuration,
    required this.knownResponseBytes,
    required this.routes,
    required this.recentEvents,
  });

  final int logicalRequests;
  final int httpAttempts;
  final int retries;
  final int refreshRequests;
  final int errors;
  final int cancellations;
  final int timeouts;
  final Duration totalDuration;
  final int knownResponseBytes;
  final Map<String, HttpRouteMetric> routes;
  final List<HttpInstrumentationEvent> recentEvents;
}
