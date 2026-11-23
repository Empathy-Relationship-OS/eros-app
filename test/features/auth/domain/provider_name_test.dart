import 'package:eros_app/features/auth/domain/models/provider_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ({String first, String last})? parts(ProviderName? name) =>
      name == null ? null : (first: name.firstName, last: name.lastName);

  test('given and family names win over the display name', () {
    expect(
      parts(ProviderName.from(givenName: 'Ada', familyName: 'Lovelace', displayName: 'A L')),
      (first: 'Ada', last: 'Lovelace'),
    );
  });

  test('the display name splits on its first space', () {
    expect(parts(ProviderName.from(displayName: 'Mary Ann Smith')), (first: 'Mary', last: 'Ann Smith'));
    expect(parts(ProviderName.from(displayName: '  Ada   Lovelace ')), (first: 'Ada', last: 'Lovelace'));
  });

  test('a one-word display name is a first name only', () {
    expect(parts(ProviderName.from(displayName: 'Cher')), (first: 'Cher', last: ''));
  });

  test('no name at all gives null', () {
    expect(ProviderName.from(), isNull);
    expect(ProviderName.from(givenName: ' ', familyName: '', displayName: '  '), isNull);
  });
}
