import 'package:flutter/foundation.dart';

/// A city users can date in, from `GET /city/all` (RFC-004 D-14).
///
/// Only the id and name are read: the city's units and travel stops come from
/// `GET /date-preferences/options` (RFC-005 D-15).
@immutable
class DatingCity {
  final int cityId;
  final String cityName;

  const DatingCity({required this.cityId, required this.cityName});

  factory DatingCity.fromJson(Map<String, dynamic> json) {
    return DatingCity(
      cityId: json['cityId'] as int,
      cityName: json['cityName'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'cityId': cityId, 'cityName': cityName};

  @override
  bool operator ==(Object other) =>
      other is DatingCity && other.cityId == cityId && other.cityName == cityName;

  @override
  int get hashCode => Object.hash(cityId, cityName);

  @override
  String toString() => 'DatingCity($cityId, $cityName)';
}
