import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/features/user/data/models/profile_dto.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/features/user/domain/repositories/profile_repository.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<Profile?> getMe() async {
    try {
      final response = await _dio.get<dynamic>('/v1/profiles/me');
      return ProfileDto.fromJson(ApiPayloadParser.dataMap(response.data)).toEntity();
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<Profile> upsertMe({
    required String displayName,
    required DateTime birthDate,
    required String gender,
    String? customGender,
    required String bio,
    required int journeyLevel,
  }) async {
    final response = await _dio.put<dynamic>(
      '/v1/profiles/me',
      data: {
        'displayName': displayName,
        'birthDate': birthDate.toIso8601String().split('T').first,
        'gender': gender,
        'customGender': customGender,
        'bio': bio,
        'journeyLevel': journeyLevel,
      },
    );

    return ProfileDto.fromJson(ApiPayloadParser.dataMap(response.data)).toEntity();
  }

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final extension = path.extension(fileName).replaceFirst('.', '').toLowerCase();
    final response = await _dio.post<dynamic>(
      '/v1/profiles/me/avatar',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: MediaType(
            'image',
            extension == 'jpg' ? 'jpeg' : extension,
          ),
        ),
      }),
      options: Options(
        headers: const {'Content-Type': 'multipart/form-data'},
      ),
    );

    return ApiPayloadParser.dataMap(response.data)['avatarUrl'].toString();
  }
}
