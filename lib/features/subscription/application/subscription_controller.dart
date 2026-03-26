import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.subscriptionBaseUrl));
  return SubscriptionRepositoryImpl(dio);
});

final subscriptionControllerProvider =
    AsyncNotifierProvider<SubscriptionController, List<SubscriptionRecord>>(
  SubscriptionController.new,
);

class SubscriptionController extends AsyncNotifier<List<SubscriptionRecord>> {
  @override
  Future<List<SubscriptionRecord>> build() async {
    return ref.watch(subscriptionRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref.read(subscriptionRepositoryProvider).list();
    });
  }

  Future<void> create({
    required String planCode,
    required String status,
    required String billingCycle,
    required bool premium,
  }) async {
    final repository = ref.read(subscriptionRepositoryProvider);
    final currentItems = state.asData?.value ?? const <SubscriptionRecord>[];

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final created = await repository.create(
        planCode: planCode,
        status: status,
        billingCycle: billingCycle,
        premium: premium,
      );

      return [created, ...currentItems];
    });
  }
}
