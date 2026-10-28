import 'package:eros_app/core/config/map_config.dart';
import 'package:flutter_test/flutter_test.dart';

const _url = 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={key}';
const _attribution = '© MapTiler © OpenStreetMap contributors';

void main() {
  group('MapConfig.resolve', () {
    test('a local build without tiles gets the grey placeholder', () {
      expect(MapConfig.resolve(env: 'local', url: '', key: '', attribution: ''), isNull);
    });

    test('the tests run as a local build without tiles', () {
      expect(MapConfig.tiles, isNull);
    });

    test('returns the configured tiles', () {
      final tiles =
          MapConfig.resolve(env: 'production', url: _url, key: 'k', attribution: _attribution)!;
      expect(tiles.urlTemplate, _url);
      expect(tiles.key, 'k');
      expect(tiles.attribution, _attribution);
    });

    for (final env in ['develop', 'beta', 'production']) {
      test('a $env build without tiles fails with the command to run', () {
        expect(
          () => MapConfig.resolve(env: env, url: '', key: '', attribution: ''),
          throwsA(isA<AssertionError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('MAP_TILE_URL, MAP_TILE_KEY, MAP_TILE_ATTRIBUTION'),
              contains('flutter run --dart-define=ENV=$env'),
            ),
          )),
        );
      });
    }

    test('each missing value is named', () {
      expect(
        () => MapConfig.resolve(env: 'beta', url: _url, key: 'k', attribution: ''),
        throwsA(isA<AssertionError>()
            .having((e) => e.message, 'message', startsWith('MAP_TILE_ATTRIBUTION must'))),
      );
      expect(
        () => MapConfig.resolve(env: 'local', url: _url, key: '', attribution: _attribution),
        throwsA(isA<AssertionError>()
            .having((e) => e.message, 'message', startsWith('MAP_TILE_KEY must'))),
      );
    });

    test('never uses OpenStreetMap\'s own tile servers, even locally', () {
      for (final env in ['local', 'production']) {
        expect(
          () => MapConfig.resolve(
            env: env,
            url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png?{key}',
            key: 'k',
            attribution: '© OpenStreetMap contributors',
          ),
          throwsA(isA<AssertionError>()),
        );
      }
    });

    test('the template needs {z}, {x}, {y} and {key}', () {
      expect(
        () => MapConfig.resolve(
          env: 'production',
          url: 'https://tiles.example.com/{z}/{x}/{y}.png',
          key: 'k',
          attribution: _attribution,
        ),
        throwsA(isA<AssertionError>()
            .having((e) => e.message, 'message', contains('{key}'))),
      );
    });

    test('the key never reaches a log through toString', () {
      final tiles =
          MapConfig.resolve(env: 'beta', url: _url, key: 'secret', attribution: _attribution)!;
      expect(tiles.toString(), isNot(contains('secret')));
    });
  });
}
