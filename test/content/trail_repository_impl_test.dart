import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/features/content/data/repositories/trail_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'list requests summary projection and parses lightweight payload',
    () async {
      final adapter = _TrailAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final repository = TrailRepositoryImpl(dio);

      final result = await repository.list(page: 0, size: 4);

      expect(
        adapter.requests.any(
          (request) =>
              request.startsWith('GET /v1/trails?') &&
              request.contains('projection=summary'),
        ),
        isTrue,
      );
      expect(result.items, hasLength(1));
      expect(result.items.single.title, 'Resumo leve');
      expect(result.items.single.stepCount, 2);
    },
  );

  test('detail requests single trail without starting journey', () async {
    final adapter = _TrailAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final repository = TrailRepositoryImpl(dio);

    final trail = await repository.detail(7);

    expect(adapter.requests, contains('GET /v1/trails/7'));
    expect(adapter.requests, isNot(contains('GET /v1/trails/7/journey')));
    expect(trail.title, 'Trilha iniciada');
  });

  test(
    'journey requests read-only state and parses missing progress',
    () async {
      final adapter = _TrailAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final repository = TrailRepositoryImpl(dio);

      final journey = await repository.journey(7);

      expect(adapter.requests, contains('GET /v1/trails/7/journey/state'));
      expect(adapter.requests, isNot(contains('GET /v1/trails/7/journey')));
      expect(
        adapter.requests,
        isNot(contains('POST /v1/trails/7/journey/start')),
      );
      expect(journey.progress, isNull);
      expect(journey.isStarted, isFalse);
    },
  );

  test('startJourney keeps explicit POST endpoint', () async {
    final adapter = _TrailAdapter(startedProgress: true);
    final dio = Dio()..httpClientAdapter = adapter;
    final repository = TrailRepositoryImpl(dio);

    final journey = await repository.startJourney(7);

    expect(adapter.requests, contains('POST /v1/trails/7/journey/start'));
    expect(journey.progress, isNotNull);
    expect(journey.isStarted, isTrue);
  });

  test('in-progress journeys falls back to current journey on 404', () async {
    final dio = Dio()..httpClientAdapter = _TrailAdapter(startedProgress: true);
    final repository = TrailRepositoryImpl(dio);

    final journeys = await repository.listInProgressJourneys();

    expect(journeys, hasLength(1));
    expect(journeys.single.trail.title, 'Trilha iniciada');
    expect(journeys.single.progressPercent, 50);
  });
}

class _TrailAdapter implements HttpClientAdapter {
  _TrailAdapter({this.startedProgress = false});

  final bool startedProgress;
  final requests = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final requestPath = options.uri.query.isEmpty
        ? options.path
        : '${options.path}?${options.uri.query}';
    requests.add('${options.method} $requestPath');
    if (options.path == '/v1/trails' &&
        options.uri.queryParameters['projection'] == 'summary') {
      return _jsonResponse({
        'data': {
          'items': [
            {
              'id': 7,
              'title': 'Resumo leve',
              'summary': 'Sem conteudo completo.',
              'category': 'foco',
              'premium': false,
              'privateTrail': false,
              'activeJourney': false,
              'generatedByAi': false,
              'stepCount': 2,
              'estimatedDurationMinutes': 8,
              'createdAt': '2026-01-01T00:00:00Z',
            },
          ],
          'page': 0,
          'size': 4,
          'totalItems': 1,
          'totalPages': 1,
          'hasNext': false,
          'hasPrevious': false,
          'sortBy': 'createdAt',
          'sortDir': 'desc',
          'filters': {},
        },
      });
    }
    if (options.path == '/v1/trails/7') {
      return _jsonResponse({'data': _trailJson()});
    }
    if (options.path == '/v1/trails/journeys/in-progress') {
      return _jsonResponse({'message': 'Not found'}, statusCode: 404);
    }
    if (options.path == '/v1/trails/journey/current') {
      return _jsonResponse({'data': _trailJson()});
    }
    if (options.path == '/v1/trails/7/journey/state' ||
        (options.method == 'POST' &&
            options.path == '/v1/trails/7/journey/start')) {
      final withProgress =
          startedProgress || options.path.endsWith('/journey/start');
      return _jsonResponse({'data': _journeyJson(withProgress: withProgress)});
    }
    return _jsonResponse({'message': 'Unexpected request'}, statusCode: 500);
  }
}

Map<String, Object?> _journeyJson({required bool withProgress}) {
  return {
    'trail': _trailJson(),
    'steps': [
      {
        'index': 0,
        'title': 'Primeiro passo',
        'type': 'REFLECTION',
        'summary': '',
        'content': '',
        'status': withProgress ? 'completed' : 'current',
        'estimatedMinutes': 5,
        'mediaLinks': [],
      },
      {
        'index': 1,
        'title': 'Proximo passo',
        'type': 'REFLECTION',
        'summary': '',
        'content': '',
        'status': withProgress ? 'current' : 'upcoming',
        'estimatedMinutes': 5,
        'mediaLinks': [],
      },
    ],
    'progress': withProgress
        ? {
            'currentStepIndex': 1,
            'completedStepIndexes': [0],
            'startedAt': '2026-01-01T00:00:00Z',
            'updatedAt': '2026-01-02T00:00:00Z',
          }
        : null,
    'progressPercent': withProgress ? 50 : 0,
    'nextStep': {
      'index': withProgress ? 1 : 0,
      'title': withProgress ? 'Proximo passo' : 'Primeiro passo',
      'type': 'REFLECTION',
      'summary': '',
      'content': '',
      'status': 'current',
      'estimatedMinutes': 5,
      'mediaLinks': [],
    },
  };
}

Map<String, Object?> _trailJson() {
  return {
    'id': 7,
    'userId': 'user-1',
    'title': 'Trilha iniciada',
    'summary': 'Uma trilha com progresso.',
    'content': '',
    'category': 'foco',
    'premium': false,
    'privateTrail': false,
    'activeJourney': false,
    'generatedByAi': false,
    'accessible': true,
    'mediaLinks': [],
    'steps': [],
    'createdAt': '2026-01-01T00:00:00Z',
  };
}

ResponseBody _jsonResponse(
  Map<String, Object?> payload, {
  int statusCode = 200,
}) {
  return ResponseBody.fromString(
    jsonEncode(payload),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
