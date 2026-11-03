import 'package:eros_app/features/chat/data/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatSignal.fromSse reads the RFC-006 §5 stream events', () {
    test('messages', () {
      final signal = ChatSignal.fromSse('messages', '{"lastSeq":19}');
      expect(signal, isA<MessagesSignal>().having((s) => s.lastSeq, 'lastSeq', 19));
    });

    test('read', () {
      final signal = ChatSignal.fromSse('read', '{"partnerLastReadSeq":18}');
      expect(signal, isA<ReadSignal>().having((s) => s.partnerLastReadSeq, 'partnerLastReadSeq', 18));
    });

    test('closed and heartbeat', () {
      expect(ChatSignal.fromSse('closed', '{}'), isA<ClosedSignal>());
      expect(ChatSignal.fromSse('heartbeat', null), isA<HeartbeatSignal>());
    });

    test('skips unknown events and data that does not parse', () {
      expect(ChatSignal.fromSse('typing', '{}'), isNull);
      expect(ChatSignal.fromSse('messages', null), isNull);
      expect(ChatSignal.fromSse('messages', 'not json'), isNull);
      expect(ChatSignal.fromSse('messages', '{"lastSeq":"19"}'), isNull);
      expect(ChatSignal.fromSse('read', '[]'), isNull);
    });
  });
}
