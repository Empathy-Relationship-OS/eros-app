import 'package:flutter/foundation.dart';

/// The hosted tile provider for maps (RFC-005 D-22, §6.5): which provider is configuration, not
/// code, so it can change without a release.
@immutable
class MapTiles {
  /// A `flutter_map` URL template with `{z}`, `{x}`, `{y}` and `{key}`, such as
  /// `https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={key}`.
  final String urlTemplate;

  /// Fills `{key}` in [urlTemplate].
  final String key;

  /// The provider's and OpenStreetMap's credit, which their licences require the map to show.
  final String attribution;

  const MapTiles({required this.urlTemplate, required this.key, required this.attribution});

  // The key is a credential, so it never reaches a log through toString.
  @override
  String toString() => 'MapTiles(<redacted>)';
}

/// Map tile configuration from `--dart-define`, like `StripeConfig`:
/// `MAP_TILE_URL`, `MAP_TILE_KEY` and `MAP_TILE_ATTRIBUTION`.
class MapConfig {
  MapConfig._();

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'local');
  static const String _url = String.fromEnvironment('MAP_TILE_URL');
  static const String _key = String.fromEnvironment('MAP_TILE_KEY');
  static const String _attribution = String.fromEnvironment('MAP_TILE_ATTRIBUTION');

  /// The tiles for this build, or null in a local build without them, where the map shows a
  /// plain grey placeholder so development works without a key.
  ///
  /// Throws an [AssertionError] with the command to run when a non-local build is missing a
  /// value, or when any build is misconfigured.
  static MapTiles? get tiles =>
      resolve(env: _env, url: _url, key: _key, attribution: _attribution);

  /// The rules behind [tiles], with the defines passed in so they can be tested.
  @visibleForTesting
  static MapTiles? resolve({
    required String env,
    required String url,
    required String key,
    required String attribution,
  }) {
    if (url.contains('tile.openstreetmap.org')) {
      throw AssertionError(
        'MAP_TILE_URL must not use OpenStreetMap\'s own tile servers: their usage policy doesn\'t '
        'allow app traffic (RFC-005 §6.5). Use a hosted provider such as MapTiler or Stadia.',
      );
    }
    if (env == 'local' && url.isEmpty) return null;

    final missing = [
      if (url.isEmpty) 'MAP_TILE_URL',
      if (key.isEmpty) 'MAP_TILE_KEY',
      if (attribution.isEmpty) 'MAP_TILE_ATTRIBUTION',
    ];
    if (missing.isNotEmpty) {
      throw AssertionError(
        '${missing.join(', ')} must be provided for $env builds. '
        'Run: flutter run --dart-define=ENV=$env '
        '--dart-define=MAP_TILE_URL=\'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={key}\' '
        '--dart-define=MAP_TILE_KEY=<your key> '
        '--dart-define=MAP_TILE_ATTRIBUTION=\'© MapTiler © OpenStreetMap contributors\'',
      );
    }
    for (final placeholder in const ['{z}', '{x}', '{y}', '{key}']) {
      if (!url.contains(placeholder)) {
        throw AssertionError('MAP_TILE_URL must contain $placeholder.');
      }
    }
    return MapTiles(urlTemplate: url, key: key, attribution: attribution);
  }
}
