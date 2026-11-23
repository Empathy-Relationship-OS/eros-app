import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/legal/data/models/user_notice.dart';
import 'package:eros_app/features/legal/data/repositories/notices_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_notices_api.dart';

void main() {
  group('NoticesRepository', () {
    test('lists the notices from GET /users/me/notices', () async {
      final api = FakeNoticesApi([fraudNotice(9), fraudNotice(7, read: true, documentUrl: null)]);

      final notices = await NoticesRepository(api).getNotices();

      expect(api.gets, ['/users/me/notices']);
      expect(notices.map((n) => n.noticeId), [9, 7]);
      expect(notices.first.kind, UserNoticeKind.fraudContactBanned);
      expect(notices.first.read, isFalse);
      expect(notices.first.documentUrl, 'https://muse.app/legal/fraud-notice');
      expect(notices.first.createdAt, DateTime.utc(2026, 11, 20, 10));
      expect(notices.last.read, isTrue);
      expect(notices.last.documentUrl, isNull);
    });

    test('an empty list is no notices', () async {
      expect(await NoticesRepository(FakeNoticesApi()).getNotices(), isEmpty);
    });

    test('reads a kind it does not know as unknown', () async {
      final api = FakeNoticesApi([fraudNotice(3, kind: 'SOMETHING_NEW')]);

      final notices = await NoticesRepository(api).getNotices();

      expect(notices.single.kind, UserNoticeKind.unknown);
    });

    test('marks a notice read with POST /users/me/notices/{id}/read', () async {
      final api = FakeNoticesApi([fraudNotice(9)]);

      await NoticesRepository(api).markRead(9);

      expect(api.posts, ['/users/me/notices/9/read']);
      expect(api.notices.single['read'], isTrue);
    });

    test('lets a 404 through', () async {
      final api = FakeNoticesApi();

      expect(() => NoticesRepository(api).markRead(1), throwsA(isA<NotFoundException>()));
    });
  });
}
