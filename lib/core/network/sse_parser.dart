import 'dart:async';
import 'dart:convert';

/// One server-sent event.
class SseEvent {
  /// The `event:` field, or `message` when there was none.
  final String event;

  /// The `data:` lines joined with `\n`, or null when the event had none (a heartbeat).
  final String? data;

  const SseEvent(this.event, [this.data]);

  @override
  bool operator ==(Object other) => other is SseEvent && other.event == event && other.data == data;

  @override
  int get hashCode => Object.hash(event, data);

  @override
  String toString() => 'SseEvent($event, ${data?.length ?? 0} chars)';
}

/// Turns the bytes of a `text/event-stream` body into [SseEvent]s (the WHATWG format).
///
/// Handles chunks split anywhere, including inside a multi-byte character or a `\r\n`,
/// `\n`, `\r` and `\r\n` line ends, comment lines and several events in one chunk. `id:`
/// and `retry:` are ignored. Unlike a browser's EventSource, an event with no data is still
/// dispatched, so heartbeats arrive. An event cut off by the end of the stream is dropped.
class SseParser extends StreamTransformerBase<List<int>, SseEvent> {
  const SseParser();

  @override
  Stream<SseEvent> bind(Stream<List<int>> stream) {
    String? event;
    List<String>? data;
    // bind, not transform: a Stream<Uint8List> (dio's body) can't take a List<int> transformer.
    final lines = const LineSplitter().bind(const Utf8Decoder(allowMalformed: true).bind(stream));
    return lines.transform(StreamTransformer<String, SseEvent>.fromHandlers(
      handleData: (line, sink) {
        if (line.isEmpty) {
          if (event != null || data != null) sink.add(SseEvent(event ?? 'message', data?.join('\n')));
          event = null;
          data = null;
          return;
        }
        if (line.startsWith(':')) return;

        final colon = line.indexOf(':');
        final field = colon < 0 ? line : line.substring(0, colon);
        var value = colon < 0 ? '' : line.substring(colon + 1);
        if (value.startsWith(' ')) value = value.substring(1);

        switch (field) {
          case 'event':
            event = value;
          case 'data':
            (data ??= []).add(value);
        }
      },
    ));
  }
}
