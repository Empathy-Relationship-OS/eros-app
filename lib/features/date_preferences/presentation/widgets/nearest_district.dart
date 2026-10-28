import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:eros_app/features/date_preferences/domain/models/city_district.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';

/// Earth's mean radius, the same as the backend's (RFC-005 primer rule 4).
const double earthRadiusMeters = 6371008.8;

/// Two district distances closer than this are a tie, and the lowest district id wins. Doubles
/// can't be compared exactly: in a true tie one side can come out about 1e-9 m closer.
const double districtTieToleranceMeters = 0.001;

/// Rounds a coordinate to 3 decimal places (about 100 m) as the server does when it saves a pin
/// (RFC-005 D-23): halves go towards positive infinity, also for negative values.
///
/// Dart's `round()` rounds halves away from zero, which differs for every US longitude.
double roundCoordinate(double value) => (value * 1000 + 0.5).floorToDouble() / 1000;

/// [point] with both coordinates rounded by [roundCoordinate].
GeoPoint roundPoint(GeoPoint point) => GeoPoint(
      latitude: roundCoordinate(point.latitude),
      longitude: roundCoordinate(point.longitude),
    );

/// Straight-line distance in metres between two points (haversine).
double haversineMeters(GeoPoint a, GeoPoint b) {
  final lat1 = _radians(a.latitude);
  final lat2 = _radians(b.latitude);
  final dLat = lat2 - lat1;
  final dLon = _radians(b.longitude - a.longitude);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadiusMeters * math.asin(math.min(1.0, math.sqrt(h)));
}

double _radians(double degrees) => degrees * math.pi / 180;

/// Where a pin falls in its city.
@immutable
sealed class DistrictLookup {
  const DistrictLookup();
}

/// The pin is in the city, and [district] has the nearest centre.
final class NearDistrict extends DistrictLookup {
  final CityDistrict district;

  /// From the rounded pin to the district's centre.
  final double distanceMeters;

  const NearDistrict(this.district, this.distanceMeters);
}

/// The pin is in the city, which has no districts yet.
final class NoDistricts extends DistrictLookup {
  const NoDistricts();
}

/// The pin is further than the city's reach from its centre, so the server would reject it.
final class OutsideCity extends DistrictLookup {
  const OutsideCity();
}

/// The district a pin belongs to, worked out the same way as the server (RFC-005 §4.4), for the
/// map's live label.
///
/// The pin is rounded with [roundCoordinate] first. It is outside the city when it is further
/// than [reachMeters] (the options' `city.reachMeters`, which differs by city) from
/// [cityCentre]. Otherwise the nearest district centre wins, ties going to the lowest id.
DistrictLookup nearestDistrict({
  required GeoPoint pin,
  required GeoPoint cityCentre,
  required int reachMeters,
  required List<CityDistrict> districts,
}) {
  final rounded = roundPoint(pin);
  if (haversineMeters(rounded, cityCentre) > reachMeters) return const OutsideCity();

  final byId = [...districts]..sort((a, b) => a.districtId.compareTo(b.districtId));
  CityDistrict? best;
  var bestDistance = double.infinity;
  for (final district in byId) {
    final distance = haversineMeters(
      rounded,
      GeoPoint(latitude: district.latitude, longitude: district.longitude),
    );
    // Visited by ascending id, so a later district only wins when it is clearly closer.
    if (distance < bestDistance - districtTieToleranceMeters) {
      best = district;
      bestDistance = distance;
    }
  }
  return best == null ? const NoDistricts() : NearDistrict(best, bestDistance);
}
