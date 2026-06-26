import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/future_message/data/repositories/future_message_repository_impl.dart';
import 'package:evolua_frontend/features/future_message/domain/repositories/future_message_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final futureMessageRepositoryProvider = Provider<FutureMessageRepository>((
  ref,
) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.emotionalBaseUrl));
  return FutureMessageRepositoryImpl(dio);
});
