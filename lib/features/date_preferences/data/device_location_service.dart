import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';

/// What asking the device for its position gave.
sealed class DeviceLocation {
  const DeviceLocation();
}

/// One position fix.
final class LocationFix extends DeviceLocation {
  final GeoPoint point;

  const LocationFix(this.point);

  // The phone's location is private (RFC-005 primer rule 15), so it never reaches a log.
  @override
  String toString() => 'LocationFix(<redacted>)';
}

/// The user refused location permission, now or before.
final class LocationRefused extends DeviceLocation {
  const LocationRefused();
}

/// Location services are off, or no fix came.
final class LocationUnavailable extends DeviceLocation {
  const LocationUnavailable();
}

/// The phone's position, used only to move the starting-point map (RFC-005 §6.5). It never
/// leaves the device and is never logged (primer rule 15).
abstract interface class DeviceLocationService {
  /// Asks for when-in-use permission if it hasn't been refused, then takes one coarse fix.
  Future<DeviceLocation> currentLocation();
}

/// [DeviceLocationService] on `geolocator`, which also asks for the permission, so location has
/// one code path on both platforms. Android declares only `ACCESS_COARSE_LOCATION`.
class GeolocatorLocationService implements DeviceLocationService {
  const GeolocatorLocationService();

  static const _timeLimit = Duration(seconds: 15);

  @override
  Future<DeviceLocation> currentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return const LocationUnavailable();

      var permission = await Geolocator.checkPermission();
      // One prompt per tap, and none once the user has refused for good.
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationRefused();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: _timeLimit,
        ),
      );
      return LocationFix(GeoPoint(latitude: position.latitude, longitude: position.longitude));
    } on Exception {
      // Timeouts and platform errors. Nothing is logged: the error could carry the position.
      return const LocationUnavailable();
    }
  }
}

final deviceLocationServiceProvider = Provider<DeviceLocationService>(
  (ref) => const GeolocatorLocationService(),
);
