import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/features/user/data/models/profile_dto.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/features/user/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<Profile>> list() async {
    final response = await _dio.get<dynamic>('/v1/profiles');

    return ApiPayloadParser.dataList(response.data)
        .map(ProfileDto.fromJson)
        .map((item) => item.toEntity())
        .toList();
  }

  @override
  Future<Profile> create({
    required String displayName,
    required String bio,
    required int journeyLevel,
    required bool premium,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/profiles',
      data: {
        'displayName': displayName,
        'bio': bio,
        'journeyLevel': journeyLevel,
        'premium': premium,
      },
    );

    return ProfileDto.fromJson(ApiPayloadParser.dataMap(response.data)).toEntity();
  }
}
