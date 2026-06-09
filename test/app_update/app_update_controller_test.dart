import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/features/app_update/application/app_update_route_state.dart';
import 'package:evolua_frontend/features/app_update/application/app_update_service.dart';
import 'package:evolua_frontend/features/app_update/application/app_version_status_controller.dart';
import 'package:evolua_frontend/features/app_update/presentation/app_update_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:evolua_frontend/features/auth/application/auth_controller.dart';

void main() {
  group('AppVersionStatusController', () {
    test('reads package info and sends query to backend', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final adapter = _VersionStatusAdapter(
        response: _envelope({
          'latestVersionCode': 22,
          'minimumSupportedVersionCode': 0,
          'updateRecommended': false,
          'updateRequired': false,
          'updateMode': 'none',
          'message': '',
          'storeUrl': AppConfig.evoluaPlayStoreUrl,
        }),
      );
      final container = _container(
        preferences: preferences,
        adapter: adapter,
        platform: 'android',
        packageInfo: _packageInfo(buildNumber: '22'),
      );
      addTearDown(container.dispose);

      final state = await container.read(appVersionStatusProvider.future);

      expect(state.versionName, '1.0.1');
      expect(state.versionCode, 22);
      expect(adapter.lastPath, '/v1/app/version-status');
      expect(adapter.lastQuery['platform'], 'android');
      expect(adapter.lastQuery['versionCode'], 22);
      expect(adapter.lastQuery['versionName'], '1.0.1');
    });

    test('offline endpoint continues without required cache', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = _container(
        preferences: preferences,
        adapter: _VersionStatusAdapter.fail(),
      );
      addTearDown(container.dispose);

      final state = await container.read(appVersionStatusProvider.future);

      expect(state.endpointFailed, isTrue);
      expect(state.status.updateRequired, isFalse);
    });

    test('recent required cache blocks when endpoint is offline', () async {
      final now = DateTime(2026, 6, 8, 10);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final key = RequiredUpdateCache.cacheKey(
        platform: 'android',
        versionCode: 22,
        apiBaseUrl: AppConfig.versionStatusBaseUrl,
      );
      await RequiredUpdateCache(preferences).write(
        key: key,
        status: const AppVersionStatus(
          latestVersionCode: 30,
          minimumSupportedVersionCode: 25,
          updateRecommended: false,
          updateRequired: true,
          updateMode: UpdateMode.immediate,
          message: 'Atualização necessária',
          storeUrl: AppConfig.evoluaPlayStoreUrl,
          disabledFeatures: ['old-chat'],
          maintenanceMode: false,
        ),
        storedAt: now.subtract(const Duration(hours: 2)),
      );
      final container = _container(
        preferences: preferences,
        adapter: _VersionStatusAdapter.fail(),
        platform: 'android',
        clock: now,
      );
      addTearDown(container.dispose);

      final state = await container.read(appVersionStatusProvider.future);

      expect(state.fromCache, isTrue);
      expect(state.status.updateRequired, isTrue);
      expect(state.status.disabledFeatures, contains('old-chat'));
    });

    test('required cache expires after ttl', () async {
      final now = DateTime(2026, 6, 8, 10);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final key = RequiredUpdateCache.cacheKey(
        platform: 'android',
        versionCode: 22,
        apiBaseUrl: AppConfig.versionStatusBaseUrl,
      );
      await RequiredUpdateCache(preferences).write(
        key: key,
        status: const AppVersionStatus(
          latestVersionCode: 30,
          minimumSupportedVersionCode: 25,
          updateRecommended: false,
          updateRequired: true,
          updateMode: UpdateMode.immediate,
          message: 'Atualização necessária',
          storeUrl: AppConfig.evoluaPlayStoreUrl,
          disabledFeatures: [],
          maintenanceMode: false,
        ),
        storedAt: now.subtract(const Duration(hours: 25)),
      );
      final container = _container(
        preferences: preferences,
        adapter: _VersionStatusAdapter.fail(),
        platform: 'android',
        clock: now,
      );
      addTearDown(container.dispose);

      final state = await container.read(appVersionStatusProvider.future);

      expect(state.status.updateRequired, isFalse);
    });

    test(
      'required cache is separated by platform version and api url',
      () async {
        final first = RequiredUpdateCache.cacheKey(
          platform: 'android',
          versionCode: 22,
          apiBaseUrl: 'https://api-a.evolua.test',
        );
        final otherPlatform = RequiredUpdateCache.cacheKey(
          platform: 'ios',
          versionCode: 22,
          apiBaseUrl: 'https://api-a.evolua.test',
        );
        final otherVersion = RequiredUpdateCache.cacheKey(
          platform: 'android',
          versionCode: 23,
          apiBaseUrl: 'https://api-a.evolua.test',
        );
        final otherApi = RequiredUpdateCache.cacheKey(
          platform: 'android',
          versionCode: 22,
          apiBaseUrl: 'https://api-b.evolua.test',
        );

        expect({first, otherPlatform, otherVersion, otherApi}, hasLength(4));
      },
    );

    test('backend response clears stale required cache', () async {
      final now = DateTime(2026, 6, 8, 10);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final key = RequiredUpdateCache.cacheKey(
        platform: 'android',
        versionCode: 22,
        apiBaseUrl: AppConfig.versionStatusBaseUrl,
      );
      await RequiredUpdateCache(preferences).write(
        key: key,
        status: const AppVersionStatus(
          latestVersionCode: 30,
          minimumSupportedVersionCode: 25,
          updateRecommended: false,
          updateRequired: true,
          updateMode: UpdateMode.immediate,
          message: 'Atualização necessária',
          storeUrl: AppConfig.evoluaPlayStoreUrl,
          disabledFeatures: [],
          maintenanceMode: false,
        ),
        storedAt: now,
      );
      final container = _container(
        preferences: preferences,
        adapter: _VersionStatusAdapter(
          response: _envelope({
            'latestVersionCode': 22,
            'minimumSupportedVersionCode': 0,
            'updateRecommended': false,
            'updateRequired': false,
            'updateMode': 'none',
            'message': '',
            'storeUrl': AppConfig.evoluaPlayStoreUrl,
          }),
        ),
        platform: 'android',
        clock: now,
      );
      addTearDown(container.dispose);

      await container.read(appVersionStatusProvider.future);

      expect(preferences.getInt('$key.storedAt'), isNull);
    });
  });

  group('AppUpdateGate', () {
    testWidgets(
      'required update shows blocking screen and tries immediate update',
      (tester) async {
        final fakeService = _FakeAppUpdateService();
        await tester.pumpWidget(
          _testApp(
            status: _requiredStatus(),
            service: fakeService,
            initialLocation: '/home',
          ),
        );
        await tester.pump();

        expect(find.text('Atualização necessária'), findsOneWidget);
        expect(fakeService.immediateCalls, 1);
      },
    );

    testWidgets('required update does not interrupt check-in route', (
      tester,
    ) async {
      final fakeService = _FakeAppUpdateService();
      await tester.pumpWidget(
        _testApp(
          status: _requiredStatus(),
          service: fakeService,
          initialLocation: '/check-in',
        ),
      );
      await tester.pump();

      expect(find.text('Check-in em andamento'), findsOneWidget);
      expect(find.text('Atualização necessária'), findsNothing);
      expect(fakeService.immediateCalls, 0);
    });

    testWidgets(
      'required update waits while a sensitive flow is active on Home',
      (tester) async {
        final fakeService = _FakeAppUpdateService();
        await tester.pumpWidget(
          _testApp(
            status: _requiredStatus(),
            service: fakeService,
            initialLocation: '/home',
            sensitiveFlow: true,
          ),
        );
        await tester.pump();

        expect(find.text('Home livre'), findsOneWidget);
        expect(find.text('Atualização necessária'), findsNothing);
        expect(fakeService.immediateCalls, 0);
      },
    );

    testWidgets('recommended update shows soft dialog and allows continue', (
      tester,
    ) async {
      final fakeService = _FakeAppUpdateService();
      await tester.pumpWidget(
        _testApp(
          status: _recommendedStatus(),
          service: fakeService,
          initialLocation: '/home',
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Nova versão disponível'), findsOneWidget);
      await tester.tap(find.text('Agora não'));
      await tester.pumpAndSettle();

      expect(find.text('Home livre'), findsOneWidget);
      expect(fakeService.flexibleCalls, 0);
    });

    testWidgets('recommended update can start flexible update', (tester) async {
      final fakeService = _FakeAppUpdateService();
      await tester.pumpWidget(
        _testApp(
          status: _recommendedStatus(),
          service: fakeService,
          initialLocation: '/home',
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Atualizar'));
      await tester.pumpAndSettle();

      expect(fakeService.flexibleCalls, 1);
    });
  });
}

ProviderContainer _container({
  required SharedPreferences preferences,
  required _VersionStatusAdapter adapter,
  String platform = 'android',
  DateTime? clock,
  PackageInfo? packageInfo,
}) {
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWith((ref) async => preferences),
      packageInfoProvider.overrideWith(
        (ref) async => packageInfo ?? _packageInfo(buildNumber: '22'),
      ),
      appUpdatePlatformProvider.overrideWithValue(platform),
      appUpdateClockProvider.overrideWithValue(
        () => clock ?? DateTime(2026, 6, 8, 10),
      ),
      appVersionDioProvider.overrideWithValue(
        Dio(BaseOptions(baseUrl: AppConfig.versionStatusBaseUrl))
          ..httpClientAdapter = adapter,
      ),
    ],
  );
}

PackageInfo _packageInfo({required String buildNumber}) {
  return PackageInfo(
    appName: 'Evolua',
    packageName: 'br.com.zenithit.evolua',
    version: '1.0.1',
    buildNumber: buildNumber,
  );
}

Map<String, dynamic> _envelope(Map<String, dynamic> data) {
  return {'status': 200, 'message': 'OK', 'data': data};
}

class _VersionStatusAdapter implements HttpClientAdapter {
  _VersionStatusAdapter({required this.response}) : fail = false;

  _VersionStatusAdapter.fail() : response = const {}, fail = true;

  final Map<String, dynamic> response;
  final bool fail;
  String? lastPath;
  Map<String, dynamic> lastQuery = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastQuery = Map<String, dynamic>.from(options.queryParameters);
    if (fail) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Widget _testApp({
  required AppVersionStatus status,
  required _FakeAppUpdateService service,
  required String initialLocation,
  bool sensitiveFlow = false,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const Text('Home livre'),
      ),
      GoRoute(
        path: '/check-in',
        builder: (context, state) => const Text('Check-in em andamento'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      appUpdateGateEnabledProvider.overrideWithValue(true),
      appUpdateCurrentRouteProvider.overrideWith(
        () => _FakeRouteController(initialLocation),
      ),
      appUpdateSensitiveFlowProvider.overrideWith(
        () => _FakeSensitiveFlowController(sensitiveFlow),
      ),
      appUpdateServiceProvider.overrideWithValue(service),
      appVersionStatusProvider.overrideWith(
        () => _FakeVersionStatusController(status),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      builder: (context, child) {
        return AppUpdateGate(child: child ?? const SizedBox.shrink());
      },
    ),
  );
}

AppVersionStatus _requiredStatus() {
  return const AppVersionStatus(
    latestVersionCode: 30,
    minimumSupportedVersionCode: 25,
    updateRecommended: false,
    updateRequired: true,
    updateMode: UpdateMode.immediate,
    message:
        'Esta versão do Evolua ficou incompatível com melhorias importantes de segurança e estabilidade. Atualize para continuar.',
    storeUrl: AppConfig.evoluaPlayStoreUrl,
    disabledFeatures: [],
    maintenanceMode: false,
  );
}

AppVersionStatus _recommendedStatus() {
  return const AppVersionStatus(
    latestVersionCode: 30,
    minimumSupportedVersionCode: 0,
    updateRecommended: true,
    updateRequired: false,
    updateMode: UpdateMode.flexible,
    message:
        'Atualize o Evolua para receber melhorias, correções e uma experiência mais estável.',
    storeUrl: AppConfig.evoluaPlayStoreUrl,
    disabledFeatures: [],
    maintenanceMode: false,
  );
}

class _FakeVersionStatusController extends AppVersionStatusController {
  _FakeVersionStatusController(this.status);

  final AppVersionStatus status;

  @override
  Future<AppVersionCheckState> build() async {
    return AppVersionCheckState(
      status: status,
      platform: 'android',
      versionCode: 22,
      versionName: '1.0.1',
      cacheKey: 'test',
      fromCache: false,
      endpointFailed: false,
      disabled: false,
    );
  }
}

class _FakeRouteController extends AppUpdateCurrentRouteController {
  _FakeRouteController(this.route);

  final String route;

  @override
  String build() => route;
}

class _FakeSensitiveFlowController extends AppUpdateSensitiveFlowController {
  _FakeSensitiveFlowController(this.sensitive);

  final bool sensitive;

  @override
  bool build() => sensitive;
}

class _FakeAppUpdateService implements AppUpdateService {
  int flexibleCalls = 0;
  int immediateCalls = 0;
  int storeCalls = 0;

  @override
  Future<bool> startFlexibleUpdate() async {
    flexibleCalls++;
    return true;
  }

  @override
  Future<bool> performImmediateUpdate() async {
    immediateCalls++;
    return true;
  }

  @override
  Future<bool> openStore(String storeUrl) async {
    storeCalls++;
    return true;
  }
}
