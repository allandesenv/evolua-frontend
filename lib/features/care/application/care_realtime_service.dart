import 'dart:async';

import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/features/care/application/care_realtime_event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

final careRealtimeServiceProvider = Provider<CareRealtimeService>((ref) {
  return StompCareRealtimeService();
});

abstract class CareRealtimeService {
  Stream<CareRealtimeEvent> connect({
    required String userId,
    required String accessToken,
  });

  Future<void> disconnect();
}

class StompCareRealtimeService implements CareRealtimeService {
  StompClient? _client;
  StreamController<CareRealtimeEvent>? _events;

  @override
  Stream<CareRealtimeEvent> connect({
    required String userId,
    required String accessToken,
  }) {
    unawaited(disconnect());
    final controller = StreamController<CareRealtimeEvent>.broadcast();
    _events = controller;

    _client = StompClient(
      config: StompConfig(
        url: '${AppConfig.careSocketUrl}/ws/care',
        reconnectDelay: const Duration(seconds: 5),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        stompConnectHeaders: accessToken.isEmpty
            ? const {}
            : {'Authorization': 'Bearer $accessToken'},
        webSocketConnectHeaders: accessToken.isEmpty
            ? const {}
            : {'Authorization': 'Bearer $accessToken'},
        onConnect: (frame) {
          _client?.subscribe(
            destination: '/topic/care/$userId',
            callback: (frame) {
              final body = frame.body;
              if (body == null || body.isEmpty) return;
              try {
                controller.add(CareRealtimeEvent.fromStompBody(body));
              } catch (error) {
                if (kDebugMode) {
                  debugPrint(
                    'Care realtime event ignored (${error.runtimeType}).',
                  );
                }
              }
            },
          );
        },
        onWebSocketError: (error) {
          if (kDebugMode) {
            debugPrint('Care realtime socket error (${error.runtimeType}).');
          }
        },
        onStompError: (frame) {
          if (kDebugMode) {
            debugPrint('Care realtime STOMP error.');
          }
        },
      ),
    );
    _client?.activate();
    return controller.stream;
  }

  @override
  Future<void> disconnect() async {
    final client = _client;
    final events = _events;
    _client = null;
    _events = null;
    if (client != null) {
      client.deactivate();
    }
    await events?.close();
  }
}
