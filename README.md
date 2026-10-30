# eros_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Developer tools

Local and develop builds can include a developer menu for manual testing: sign in as test
users ("personas") without registering, move the backend clock forward, and run named
scenarios that put the backend into a known state. The backend side is described in
`eros-backend/docs/RFC-003-dev-tooling.md`.

Run the app with devtools compiled in:

```bash
flutter run --dart-define=ENV=local --dart-define=DEVTOOLS=true --dart-define=DEVTOOLS_KEY=<same as backend>
```

- The backend must be started with `DEVTOOLS_ENABLED=true` and the same `DEVTOOLS_KEY`
  (at least 16 characters). Otherwise the dev menu header shows "Devtools off".
- Open the menu with the draggable **DEV** button shown on every screen (it works while signed
  out), or from **App Settings > Developer tools**.
- Without `DEVTOOLS_KEY` the menu shows "DEVTOOLS_KEY not set" and sends no requests.

Devtools are gated by the compile-time constant `DevtoolsConfig.enabled`
(`lib/features/devtools/devtools_config.dart`), which is true only when `DEVTOOLS=true` and
`ENV` is `local` or `develop`. In every other build (including `ENV=beta` or
`ENV=production` with `DEVTOOLS=true`) the constant is false, so the guarded code is removed
by the compiler: there is no DEV button, no `/dev` route and no dev HTTP client in the binary.

## Map tiles

The starting-point map (date preferences, RFC-005 §6.5) uses `flutter_map` with a hosted tile
provider such as MapTiler, Stadia or Mapbox. The provider is build configuration, read by
`MapConfig` (`lib/core/config/map_config.dart`):

| Define | What it is |
|---|---|
| `MAP_TILE_URL` | Tile URL template with `{z}`, `{x}`, `{y}` and `{key}`, e.g. `https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={key}` |
| `MAP_TILE_KEY` | The provider's API key, filled into `{key}` |
| `MAP_TILE_ATTRIBUTION` | The credit the map always shows, e.g. `© MapTiler © OpenStreetMap contributors` |

```bash
flutter run --dart-define=ENV=develop \
  --dart-define=MAP_TILE_URL='https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={key}' \
  --dart-define=MAP_TILE_KEY=<your key> \
  --dart-define=MAP_TILE_ATTRIBUTION='© MapTiler © OpenStreetMap contributors'
```

- A local build (`ENV=local`) without `MAP_TILE_URL` shows a plain grey map, so development
  works without a key.
- Any other build without all three values throws when the map opens, with the command to run.
- Never use OpenStreetMap's own tile servers (`tile.openstreetmap.org`): their usage policy
  doesn't allow app traffic, and `MapConfig` rejects them.
- Don't commit a key. A tile key ships inside the app, so restrict it in the provider's console
  to the app's bundle id (`com.eros.eros_app`) and set a usage cap.
