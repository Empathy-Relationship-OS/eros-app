import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/domain/models/update_user_request.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ethnicity is optional (RFC-009 D-12, CF-B11): no answer is an empty list, and
/// "Prefer not to say" can't be combined with another value.
void main() {
  UpdateUserRequest request(List<Ethnicity> field) =>
      UpdateUserRequest(ethnicity: DisplayableField(field: field, visible: false));

  test('no answer sends an empty list', () {
    expect(request([]).toJson(), {
      'ethnicity': {'field': <String>[], 'display': false},
    });
  });

  test('"Prefer not to say" on its own is sent as the backend\'s display name', () {
    expect(request([Ethnicity.preferNotToSay]).toJson(), {
      'ethnicity': {'field': ['Prefer not to say'], 'display': false},
    });
  });

  test('"Prefer not to say" with another answer is rejected, as the backend would', () {
    expect(() => request([Ethnicity.eastAsian, Ethnicity.preferNotToSay]), throwsArgumentError);
  });

  test('several real answers are still allowed', () {
    expect(() => request([Ethnicity.eastAsian, Ethnicity.whiteCaucasian]), returnsNormally);
  });
}
