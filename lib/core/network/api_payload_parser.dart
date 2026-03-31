import 'package:evolua_frontend/core/network/paginated_response.dart';

class ApiPayloadParser {
  const ApiPayloadParser._();

  static Map<String, dynamic> dataMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final payload = raw['data'];

      if (payload is Map<String, dynamic>) {
        return payload;
      }
    }

    throw const FormatException('Resposta inesperada da API.');
  }

  static List<Map<String, dynamic>> dataList(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final payload = raw['data'];

      if (payload is List) {
        return payload
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }

      if (payload is Map<String, dynamic> && payload['items'] is List) {
        return (payload['items'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }

    throw const FormatException('Lista inesperada da API.');
  }

  static PaginatedResponse<T> paginatedData<T>(
    dynamic raw,
    T Function(Map<String, dynamic> item) decoder,
  ) {
    final payload = dataMap(raw);
    final items = (payload['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => decoder(Map<String, dynamic>.from(item)))
        .toList();

    return PaginatedResponse<T>(
      items: items,
      page: (payload['page'] as num?)?.toInt() ?? 0,
      size: (payload['size'] as num?)?.toInt() ?? items.length,
      totalItems: (payload['totalItems'] as num?)?.toInt() ?? items.length,
      totalPages: (payload['totalPages'] as num?)?.toInt() ?? 1,
      hasNext: payload['hasNext'] as bool? ?? false,
      hasPrevious: payload['hasPrevious'] as bool? ?? false,
      sortBy: payload['sortBy'] as String? ?? 'createdAt',
      sortDir: payload['sortDir'] as String? ?? 'desc',
      filters: Map<String, dynamic>.from(payload['filters'] as Map? ?? const {}),
    );
  }
}
