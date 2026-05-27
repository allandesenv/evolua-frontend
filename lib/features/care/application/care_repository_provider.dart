import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/care/data/repositories/care_repository_impl.dart';
import 'package:evolua_frontend/features/care/domain/repositories/care_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final careRepositoryProvider = Provider<CareRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.apiBaseUrl));
  return CareRepositoryImpl(dio);
});
