import 'dart:convert';
import 'dart:io';

import 'package:eros_app/core/utils/user_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// `test/fixtures/text/user_text_cases.json` is an unchanged copy of
/// `eros-backend/docs/tasks/profile-editing/user-text-cases.json` (RFC-004 D-16). The backend's
/// `UserTextTest` runs the same cases, so the two implementations can't drift apart. When the
/// cases change, copy the file across again.
final Map<String, dynamic> _cases =
    jsonDecode(File('test/fixtures/text/user_text_cases.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('shared cases: clean', () {
    for (final c in (_cases['clean'] as List).cast<Map<String, dynamic>>()) {
      test(c['name'] as String, () {
        expect(UserText.clean(c['input'] as String, multiline: c['multiline'] as bool), c['expected']);
      });
    }
  });

  group('shared cases: length', () {
    for (final c in (_cases['length'] as List).cast<Map<String, dynamic>>()) {
      test(c['name'] as String, () {
        expect(UserText.length(c['text'] as String), c['codePoints']);
      });
    }
  });

  test('there are cases to run', () {
    expect((_cases['clean'] as List).length, greaterThanOrEqualTo(17));
    expect((_cases['length'] as List).length, greaterThanOrEqualTo(5));
  });

  group('UserText.validate', () {
    test('passes clean text', () {
      expect(UserText.validate("O'Brien", name: 'Last name', maxLength: 100, required: true), isNull);
    });

    test('names the field when required text is empty after cleaning', () {
      expect(UserText.validate(' \u200b\t ', name: 'City', maxLength: 100, required: true), 'City is required');
    });

    test('allows optional text to be empty', () {
      expect(UserText.validate('   ', name: 'Occupation', maxLength: 100), isNull);
      expect(UserText.validate(null, name: 'Occupation', maxLength: 100), isNull);
    });

    test('names the field and the limit when the text is too long', () {
      expect(
        UserText.validate('a' * 101, name: 'Occupation', maxLength: 100),
        'Occupation must not exceed 100 characters',
      );
    });

    test('counts code points, so 100 emoji fit a limit of 100', () {
      final emoji = '\u{1F44D}' * 100;
      expect(emoji.length, 200);
      expect(UserText.validate(emoji, name: 'Bio', maxLength: 100), isNull);
    });

    test('checks the length after cleaning', () {
      expect(UserText.validate('  ${'a' * 100}  ', name: 'City', maxLength: 100), isNull);
    });
  });
}
