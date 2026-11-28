import 'package:cryptography/cryptography.dart';
import 'package:evolua_frontend/core/private_core/private_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('evolua/private_store_v1');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late SecretKeyData dek;
  final calls = <MethodCall>[];

  setUp(() {
    dek = SecretKeyData.random(length: 32);
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'create':
        case 'open':
          return 'synthetic-session';
        case 'insertBatch':
          return (call.arguments as Map)['records'].length;
        case 'page':
          return [{'id': 'r1', 'createdAt': 1, 'body': 'synthetic'}];
        case 'close':
          return null;
        default:
          throw StateError('Unexpected call');
      }
    });
  });
  tearDown(() {
    dek.destroy();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('default disabled sends no native call', () async {
    await expectLater(const PrivateStore().open('p1', dek), throwsUnsupportedError);
    expect(calls, isEmpty);
  });

  test('invalid profile or key rejected before native call', () async {
    const store = PrivateStore(enabled: true);
    await expectLater(store.open('../p1', dek), throwsArgumentError);
    final shortKey = SecretKeyData.random(length: 16);
    try {
      await expectLater(store.open('p1', shortKey), throwsArgumentError);
    } finally {
      shortKey.destroy();
    }
    expect(calls, isEmpty);
  });

  test('typed batch, keyset cursor and closed session', () async {
    final session = await const PrivateStore(enabled: true).create('p1', dek);
    final record = PrivateRecord(id: 'r1', createdAt: 1, body: 'synthetic');
    await session.insertBatch([record]);
    final page = await session.page(before: record);
    expect(page.single.id, 'r1');
    expect((calls.last.arguments as Map)['beforeId'], 'r1');
    expect((calls.last.arguments as Map)['beforeTime'], 1);
    await session.close();
    await session.close();
    await expectLater(session.page(), throwsStateError);
    expect(calls.map((call) => call.method),
        ['create', 'insertBatch', 'page', 'close']);
  });

  test('native error never triggers create or fallback', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      throw PlatformException(code: 'PROFILE_MISSING');
    });
    await expectLater(const PrivateStore(enabled: true).open('p1', dek),
        throwsA(isA<PlatformException>()));
    expect(calls.map((call) => call.method), ['open']);
  });

  test('batch and page bounds enforced locally', () async {
    final session = await const PrivateStore(enabled: true).open('p1', dek);
    await expectLater(session.insertBatch([]), throwsArgumentError);
    await expectLater(session.page(limit: 101), throwsArgumentError);
    await session.close();
    expect(calls.map((call) => call.method), ['open', 'close']);
  });
}
