import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/network/pagination_query.dart';
import 'package:evolua_frontend/features/emotional/data/models/check_in_dto.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/repositories/check_in_repository.dart';

class CheckInRepositoryImpl implements CheckInRepository {
  const CheckInRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<PaginatedResponse<CheckIn>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? mood,
    String? energyRange,
    DateTime? from,
    DateTime? to,
  }) async {
    final query = PaginationQuery(
      page: page,
      size: size,
      search: search,
      sortBy: sortBy,
      sortDir: sortDir,
    );

    final response = await _dio.get<dynamic>(
      '/v1/check-ins',
      queryParameters: query.toQueryParameters({
        'mood': mood,
        'energyRange': energyRange,
        'from': _formatDate(from),
        'to': _formatDate(to),
      }),
    );

    return ApiPayloadParser.paginatedData(
      response.data,
      (item) => CheckInDto.fromJson(item).toEntity(),
    );
  }

  @override
  Future<CheckIn> create({
    required String mood,
    required String reflection,
    required int energyLevel,
    required String recommendedPractice,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/check-ins',
      data: {
        'mood': mood,
        'reflection': reflection,
        'energyLevel': energyLevel,
        'recommendedPractice': recommendedPractice,
      },
    );

    return CheckInDto.fromJson(ApiPayloadParser.dataMap(response.data)).toEntity();
  }

  String? _formatDate(DateTime? value) {
    if (value == null) {
      return null;
    }

    final normalized = DateTime(value.year, value.month, value.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }
}
