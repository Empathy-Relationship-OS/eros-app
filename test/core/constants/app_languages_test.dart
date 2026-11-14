import 'package:eros_app/core/constants/languages.dart';
import 'package:eros_app/features/settings/domain/models/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLanguages', () {
    test('offers only English and Spanish', () {
      expect(AppLanguages.all.map((l) => l.code), ['en', 'es']);
    });

    test('is separate from the languages a user can speak', () {
      expect(Languages.all.length, greaterThan(AppLanguages.all.length));
      expect(Languages.all.map((l) => l.code), contains('fr'));
    });

    test('falls back to English for a code the app is not shown in', () {
      expect(AppLanguages.getByCode('es').code, 'es');
      expect(AppLanguages.getByCode('fr').code, 'en');
    });
  });

  group('AppSettings.fromJson', () {
    test('keeps a saved Spanish setting', () {
      final settings = AppSettings.fromJson({'languageCode': 'es'});
      expect(settings.language.code, 'es');
    });

    test('turns a language saved before the list was cut into English', () {
      final settings = AppSettings.fromJson({'languageCode': 'ja'});
      expect(settings.language.code, 'en');
    });
  });
}
