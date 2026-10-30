import 'dart:convert';
import 'dart:io';

import 'package:eros_app/features/profile/domain/models/my_profile.dart';

/// The `GET /users/me` fixture with its diet and alcohol answers replaced, for suggestions from
/// the profile.
MyProfile profileWith({String? diet = 'Omnivore', String? alcohol = 'Sometimes'}) {
  final json = jsonDecode(File('test/fixtures/users/get_users_me.json').readAsStringSync())
      as Map<String, dynamic>;
  (json['diet'] as Map<String, dynamic>)['field'] = diet;
  (json['alcoholConsumption'] as Map<String, dynamic>)['field'] = alcohol;
  return MyProfile.fromJson(json);
}
