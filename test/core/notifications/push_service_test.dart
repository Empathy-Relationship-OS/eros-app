import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/notifications/messaging_client.dart';
import 'package:eros_app/core/notifications/push_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_messaging.dart';

void main() {
  late FakeMessagingClient messaging;
  late FakeDevicesApi api;
  late PushService service;

  setUp(() {
    messaging = FakeMessagingClient();
    api = FakeDevicesApi(log: messaging.log);
    service = PushService(messaging: messaging, apiClient: () => api, platform: 'IOS')..start();
  });

  tearDown(() => service.dispose());

  group('syncToken', () {
    test('posts the token and platform on sign-in (and at startup for a signed-in user)', () async {
      await service.userChanged('alice');

      expect(api.posts, hasLength(1));
      expect(api.posts.single.path, '/users/me/devices');
      expect(api.posts.single.data, {'token': 'fcm-token-1', 'platform': 'IOS'});
    });

    test('posts nothing while signed out', () async {
      await service.userChanged(null);
      await service.syncToken();

      expect(api.posts, isEmpty);
    });

    test('the same user again does not post twice', () async {
      await service.userChanged('alice');
      await service.userChanged('alice');

      expect(api.posts, hasLength(1));
    });

    test('a new user gets the token posted again', () async {
      await service.userChanged('alice');
      await service.userChanged(null);
      await service.userChanged('bob');

      expect(api.posts, hasLength(2));
    });

    test('posts the new token on refresh', () async {
      await service.userChanged('alice');
      messaging.tokenRefresh.add('fcm-token-2');
      await pumpEventQueue();

      expect(api.posts.last.data, {'token': 'fcm-token-2', 'platform': 'IOS'});
    });

    test('a refresh while signed out is not posted', () async {
      messaging.tokenRefresh.add('fcm-token-2');
      await pumpEventQueue();

      expect(api.posts, isEmpty);
    });

    test('no token yet (iOS before APNs) posts nothing, and the token posts when it arrives', () async {
      messaging.token = null;
      await service.userChanged('alice');
      expect(api.posts, isEmpty);

      messaging.tokenRefresh.add('fcm-token-late');
      await pumpEventQueue();

      expect(api.posts.single.data, {'token': 'fcm-token-late', 'platform': 'IOS'});
    });

    test('a failed post is swallowed', () async {
      api.error = ServerException('down');

      await expectLater(service.userChanged('alice'), completes);
    });
  });

  group('removeToken', () {
    test('posts the token to /remove, then deletes it locally', () async {
      await service.userChanged('alice');
      messaging.log.clear();

      await service.removeToken();

      expect(api.posts.last.path, '/users/me/devices/remove');
      expect(api.posts.last.data, {'token': 'fcm-token-1'});
      expect(messaging.log, ['POST /users/me/devices/remove', 'deleteToken']);
    });

    test('still deletes the token locally when the post fails, and never throws', () async {
      await service.userChanged('alice');
      api.error = NetworkException('offline');
      messaging.log.clear();

      await expectLater(service.removeToken(), completes);

      expect(messaging.log, ['POST /users/me/devices/remove', 'deleteToken']);
    });

    test('a refresh during sign-out is not posted to the old account', () async {
      await service.userChanged('alice');
      await service.removeToken();
      api.posts.clear();

      messaging.tokenRefresh.add('fcm-token-2');
      await pumpEventQueue();

      expect(api.posts, isEmpty);
    });
  });

  group('requestPermission', () {
    test('syncs the token once granted', () async {
      await service.userChanged('alice');
      api.posts.clear();

      expect(await service.requestPermission(), PushPermission.granted);
      expect(messaging.requestPermissionCalls, 1);
      expect(api.posts.single.path, '/users/me/devices');
    });

    test('does not sync when denied', () async {
      await service.userChanged('alice');
      api.posts.clear();
      messaging.permissionAfterRequest = PushPermission.denied;

      expect(await service.requestPermission(), PushPermission.denied);
      expect(api.posts, isEmpty);
    });
  });
}
