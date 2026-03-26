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
    }

    throw const FormatException('Lista inesperada da API.');
  }
}
