import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/features/daily_ritual/data/repositories/daily_ritual_repository_impl.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'list calls daily rituals interval endpoint and decodes data list',
    () async {
      final adapter = _DailyRitualAdapter();
      final repository = DailyRitualRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
      );

      final items = await repository.list(
        start: DateTime(2026, 5, 7, 21),
        end: DateTime(2026, 5, 7, 23, 59),
      );

      expect(adapter.requests, hasLength(1));
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/v1/daily-rituals');
      expect(request.queryParameters, {
        'start': '2026-05-07',
        'end': '2026-05-07',
      });
      expect(adapter.todayCalls, 0);
      expect(items, hasLength(2));
      expect(items.first.type, DailyRitualType.morning);
      expect(items.last.type, DailyRitualType.evening);
    },
  );
}

class _DailyRitualAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int todayCalls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path == '/v1/daily-rituals/today') {
      todayCalls++;
      return _jsonResponse({'data': null});
    }
    if (options.path == '/v1/daily-rituals') {
      return _jsonResponse({
        'data': [
          _ritualJson(id: 1, type: DailyRitualType.morning),
          _ritualJson(id: 2, type: DailyRitualType.evening),
        ],
      });
    }
    return _jsonResponse({'message': 'not found'}, statusCode: 404);
  }
}

Map<String, Object?> _ritualJson({required int id, required String type}) {
  return {
    'id': id,
    'localDate': '2026-05-07',
    'type': type,
    'emotionalState': 'calmo',
    'dayNeed': 'clareza',
    'intention': 'agir com calma',
    'microAction': 'pausar',
    'createdAt': '2026-05-07T08:00:00Z',
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
