import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiPayloadParser', () {
    test('reads canonical paginated payload with items and totalItems', () {
      final result = ApiPayloadParser.paginatedData<int>(
        {
          'data': {
            'items': [
              {'id': 1},
              {'id': 2},
            ],
            'page': 0,
            'size': 20,
            'totalItems': 2,
            'totalPages': 1,
          },
        },
        (item) => item['id'] as int,
      );

      expect(result.items, [1, 2]);
      expect(result.totalItems, 2);
    });

    test('keeps fallback for content and totalElements payloads', () {
      final result = ApiPayloadParser.paginatedData<int>(
        {
          'data': {
            'content': [
              {'id': 7},
            ],
            'page': 0,
            'size': 20,
            'totalElements': 1,
            'totalPages': 1,
          },
        },
        (item) => item['id'] as int,
      );

      expect(result.items, [7]);
      expect(result.totalItems, 1);
    });
  });
}
