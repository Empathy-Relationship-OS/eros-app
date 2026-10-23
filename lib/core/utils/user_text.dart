import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Cleaning and checking for free text that users type: names, home city, occupation, bio, the
/// brain and body descriptions, Q&A answers and the date cancellation reason (RFC-004 D-16).
///
/// The same rules as the backend's `UserText` (PE-B10), which is the real gate; the app applies
/// them so problems show while the user types. They clean text without changing what it says:
/// apostrophes, quotes, `;`, `<`, `>`, `&`, every script and accent, and emoji are all kept.
/// Nothing is escaped or blocklisted: the backend uses parameterised queries, and the app shows
/// text in plain `Text` widgets.
///
/// The specification is `eros-backend/docs/tasks/profile-editing/user-text-cases.json`, copied
/// to `test/fixtures/text/user_text_cases.json`. Both repos' tests run every case.
class UserText {
  UserText._();

  static final RegExp _multipleSpaces = RegExp(r' {2,}');
  static final RegExp _threeOrMoreNewlines = RegExp(r'\n{3,}');

  /// Cleans [raw] by D-16, in this order:
  /// 1. line endings `\r\n` and `\r` become `\n`;
  /// 2. Unicode NFC;
  /// 3. control characters (except `\t` and `\n`), zero-width spaces, word joiners, byte-order
  ///    marks, and text-direction overrides and isolates are removed. The zero-width joiner
  ///    (inside emoji) and the left-to-right and right-to-left marks are kept;
  /// 4. `\t` becomes a space, and so does `\n` unless [multiline];
  /// 5. runs of spaces collapse to one, and each line is trimmed;
  /// 6. for [multiline] text, three or more `\n` in a row become two (one blank line);
  /// 7. the whole string is trimmed.
  static String clean(String raw, {bool multiline = false}) {
    final unified = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final normalised = unorm.nfc(unified);

    final kept = StringBuffer();
    for (final rune in normalised.runes) {
      if (_isRemoved(rune)) continue;
      if (rune == 0x09 || (rune == 0x0A && !multiline)) {
        kept.write(' ');
      } else {
        kept.writeCharCode(rune);
      }
    }

    final lines = kept.toString().split('\n').map((line) => _trimSpaces(line.replaceAll(_multipleSpaces, ' ')));
    final joined = lines.join('\n');
    final collapsed = multiline ? joined.replaceAll(_threeOrMoreNewlines, '\n\n') : joined;
    return collapsed.trim();
  }

  /// The length of [text] in Unicode code points, as the backend and Postgres count it. Dart's
  /// `String.length` counts UTF-16 units, so it would count an emoji as 2.
  static int length(String text) => text.runes.length;

  /// Checks [raw] the way the backend's `UserText.field` does, after cleaning it.
  ///
  /// Returns "[name] is required" when [required] and the cleaned text is empty, "[name] must
  /// not exceed [maxLength] characters" when it is longer than [maxLength] code points, and null
  /// when it is fine. Use it as a `TextFormField` validator.
  static String? validate(
    String? raw, {
    required String name,
    required int maxLength,
    bool required = false,
    bool multiline = false,
  }) {
    final cleaned = clean(raw ?? '', multiline: multiline);
    if (cleaned.isEmpty) return required ? '$name is required' : null;
    if (length(cleaned) > maxLength) return '$name must not exceed $maxLength characters';
    return null;
  }

  /// Trims only spaces from the ends, like the backend's `trim(' ')`. Marks such as U+200E at
  /// the end of a line are kept.
  static String _trimSpaces(String line) {
    var start = 0;
    var end = line.length;
    while (start < end && line.codeUnitAt(start) == 0x20) {
      start++;
    }
    while (end > start && line.codeUnitAt(end - 1) == 0x20) {
      end--;
    }
    return line.substring(start, end);
  }

  static bool _isRemoved(int rune) {
    if (rune == 0x09 || rune == 0x0A) return false;
    if (rune <= 0x1F || (rune >= 0x7F && rune <= 0x9F)) return true; // C0 and C1 controls
    if (rune == 0x200B || rune == 0x2060 || rune == 0xFEFF) return true; // zero-width space, word joiner, BOM
    if (rune >= 0x202A && rune <= 0x202E) return true; // direction embeddings and overrides
    if (rune >= 0x2066 && rune <= 0x2069) return true; // direction isolates
    return false;
  }
}
