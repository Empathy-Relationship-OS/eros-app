import 'package:flutter/foundation.dart';

/// A named district of a city and its centre, from `GET /city/{id}/districts` (RFC-005 §4.4).
///
/// A pin belongs to the district with the nearest centre.
@immutable
class CityDistrict {
  final int districtId;
  final String name;
  final double latitude;
  final double longitude;

  const CityDistrict({
    required this.districtId,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  factory CityDistrict.fromJson(Map<String, dynamic> json) {
    return CityDistrict(
      districtId: json['districtId'] as int,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'districtId': districtId,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
      };

  CityDistrict copyWith({int? districtId, String? name, double? latitude, double? longitude}) {
    return CityDistrict(
      districtId: districtId ?? this.districtId,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CityDistrict &&
      other.districtId == districtId &&
      other.name == name &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(districtId, name, latitude, longitude);

  @override
  String toString() => 'CityDistrict($districtId, $name)';
}
