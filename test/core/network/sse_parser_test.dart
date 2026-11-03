import 'dart:convert';

import 'package:eros_app/core/network/sse_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parses [chunks] as they would arrive off the wire.
Future<List<SseEvent>> _parse(List<List<int>> chunks) =>
    const SseParser().bind(Stream.fromIterable(chunks)).toList();

List<int> _bytes(String text) => utf8.encode(text);

void main() {
  test('parses an event with its data', () async {
    final events = await _parse([_bytes('event: messages\ndata: {"lastSeq":19}\n\n')]);

    expect(events, [const SseEvent('messages', '{"lastSeq":19}')]);
  });

  test('dispatches an event with no data, like the heartbeat', () async {
    final events = await _parse([_bytes('event: heartbeat\n\n')]);

    expect(events, [const SseEvent('heartbeat')]);
  });

  test('reassembles an event split across many chunks', () async {
    final whole = _bytes('event: read\ndata: {"partnerLastReadSeq":7}\n\n');
    final oneByteAtATime = [for (final b in whole) [b]];

    expect(await _parse(oneByteAtATime), [const SseEvent('read', '{"partnerLastReadSeq":7}')]);
  });

  test('keeps a multi-byte character split across two chunks', () async {
    final whole = _bytes('data: café 👋\n\n');
    // Split inside the four bytes of the emoji.
    final cut = whole.length - 4;

    expect(await _parse([whole.sublist(0, cut), whole.sublist(cut)]), [const SseEvent('message', 'café 👋')]);
  });

  test('skips comment lines', () async {
    final events = await _parse([_bytes(': keep-alive\nevent: closed\n: another\ndata: {}\n\n')]);

    expect(events, [const SseEvent('closed', '{}')]);
  });

  test('a comment on its own dispatches nothing', () async {
    expect(await _parse([_bytes(': ping\n\n')]), isEmpty);
  });

  test('parses several events in one chunk', () async {
    final events = await _parse([
      _bytes('event: messages\ndata: {"lastSeq":1}\n\nevent: heartbeat\n\nevent: messages\ndata: {"lastSeq":2}\n\n'),
    ]);

    expect(events, [
      const SseEvent('messages', '{"lastSeq":1}'),
      const SseEvent('heartbeat'),
      const SseEvent('messages', '{"lastSeq":2}'),
    ]);
  });

  test('handles \\r\\n line ends, even split between chunks', () async {
    final events = await _parse([
      _bytes('event: messages\r'),
      _bytes('\ndata: {"lastSeq":3}\r\n\r'),
      _bytes('\nevent: closed\r\n\r\n'),
    ]);

    expect(events, [const SseEvent('messages', '{"lastSeq":3}'), const SseEvent('closed')]);
  });

  test('joins several data lines with newlines, and takes values without a space', () async {
    final events = await _parse([_bytes('event:x\ndata:a\ndata: b\ndata\n\n')]);

    expect(events, [const SseEvent('x', 'a\nb\n')]);
  });

  test('ignores id, retry and unknown fields', () async {
    final events = await _parse([_bytes('id: 5\nretry: 1000\nfoo: bar\nevent: messages\ndata: {}\n\n')]);

    expect(events, [const SseEvent('messages', '{}')]);
  });

  test('drops an event cut off by the end of the stream', () async {
    final events = await _parse([_bytes('event: messages\ndata: {"lastSeq":1}\n\nevent: messages\ndata: {"la')]);

    expect(events, [const SseEvent('messages', '{"lastSeq":1}')]);
  });
}
