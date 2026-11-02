import 'dart:async';

import 'package:dio/dio.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/notifications/messaging_client.dart';

/// A [MessagingClient] driven by the test: push tokens, permission answers and messages.
class FakeMessagingClient implements MessagingClient {
  FakeMessagingClient({this.token = 'fcm-token-1', this.initialMessage});

  String? token;
  PushMessage? initialMessage;
  PushPermission permission = PushPermission.notDetermined;
  PushPermission permissionAfterRequest = PushPermission.granted;

  int requestPermissionCalls = 0;

  /// Every call, in order, shared with other fakes so tests can check ordering.
  List<String> log = [];

  final StreamController<String> tokenRefresh = StreamController<String>.broadcast();
  final StreamController<PushMessage> foreground = StreamController<PushMessage>.broadcast();
  final StreamController<PushMessage> opened = StreamController<PushMessage>.broadcast();

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> deleteToken() async {
    log.add('deleteToken');
    token = null;
  }

  @override
  Stream<String> get onTokenRefresh => tokenRefresh.stream;

  @override
  Future<PushPermission> requestPermission() async {
    requestPermissionCalls++;
    permission = permissionAfterRequest;
    return permission;
  }

  @override
  Future<PushPermission> permissionStatus() async => permission;

  @override
  Future<PushMessage?> getInitialMessage() async => initialMessage;

  @override
  Stream<PushMessage> get onMessage => foreground.stream;

  @override
  Stream<PushMessage> get onMessageOpenedApp => opened.stream;
}

/// Answers `POST /users/me/devices` and `/remove` with 204, the RFC-006 §5 contract, or throws
/// [error]. Records each request.
class FakeDevicesApi implements ApiClient {
  FakeDevicesApi({List<String>? log}) : log = log ?? [];

  final List<String> log;
  final List<({String path, dynamic data})> posts = [];
  ApiException? error;

  /// When set, requests wait for it, to simulate a hanging network.
  Completer<void>? gate;

  @override
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    log.add('POST $path');
    posts.add((path: path, data: data));
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return null as T;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PushMessage push(String? type, {String? dateId = '42', String? title = 'Muse', String? body = 'New message from Alex'}) =>
    PushMessage(
      title: title,
      body: body,
      data: {'type': ?type, 'dateId': ?dateId},
    );
