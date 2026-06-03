import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/features/content/data/repositories/trail_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('in-progress journeys falls back to current journey on 404', () async {
    final dio = Dio()..httpClientAdapter = _TrailAdapter();
    final repository = TrailRepositoryImpl(dio);

    final journeys = await repository.listInProgressJourneys();

    expect(journeys, hasLength(1));
    expect(journeys.single.trail.title, 'Trilha iniciada');
    expect(journeys.single.progressPercent, 50);
  });
}

class _TrailAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/v1/trails/journeys/in-progress') {
      return _jsonResponse({'message': 'Not found'}, statusCode: 404);
    }
    if (options.path == '/v1/trails/journey/current') {
      return _jsonResponse({'data': _trailJson()});
    }
    if (options.path == '/v1/trails/7/journey') {
      return _jsonResponse({
        'data': {
          'trail': _trailJson(),
          'steps': [
            {
              'index': 0,
              'title': 'Primeiro passo',
              'type': 'REFLECTION',
              'summary': '',
              'content': '',
              'status': 'completed',
              'estimatedMinutes': 5,
              'mediaLinks': [],
            },
            {
              'index': 1,
              'title': 'Próximo passo',
              'type': 'REFLECTION',
              'summary': '',
              'content': '',
              'status': 'current',
              'estimatedMinutes': 5,
              'mediaLinks': [],
            },
          ],
          'progress': {
            'currentStepIndex': 1,
            'completedStepIndexes': [0],
            'startedAt': '2026-01-01T00:00:00Z',
            'updatedAt': '2026-01-02T00:00:00Z',
          },
          'progressPercent': 50,
          'nextStep': {
            'index': 1,
            'title': 'Próximo passo',
            'type': 'REFLECTION',
            'summary': '',
            'content': '',
            'status': 'current',
            'estimatedMinutes': 5,
            'mediaLinks': [],
          },
        },
      });
    }
    return _jsonResponse({'message': 'Unexpected request'}, statusCode: 500);
  }
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
