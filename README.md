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

## Testing sign-in by hand

The app offers Continue with Apple (iOS only), Continue with Google (iOS and Android) and
Continue with Email ([RFC-011](https://github.com/Empathy-Relationship-OS/eros-backend/blob/develop/docs/RFC-011-social-sign-in.md)).
How the code works is in `CLAUDE.md` under "Authentication and social sign-in".

**Not testable yet: real Apple and Google sign-in need SI-C1's console setup, which isn't
done.** SI-C1
([brief](https://github.com/Empathy-Relationship-OS/eros-backend/blob/develop/docs/tasks/social-sign-in/SI-C1-console-setup.md),
RFC-011 §5.1) turns on the Apple and Google providers in Firebase, adds the Sign in with Apple
capability, Services ID and key in the Apple Developer account, registers the Android SHA
fingerprints, and replaces the debug signing that release builds still use
(`android/app/build.gradle.kts`). Until then the buttons show "isn't available right now" or
"couldn't sign you in", and email sign-in is the only one that works end to end.

**Use test accounts, never personal ones.** Personas from the developer menu sign in with custom
tokens and can't exercise Apple or Google, so use a Google account and an Apple ID made for
testing. Their passwords live in the team password manager, never in the repo, a PR or a chat.
Don't paste tokens, authorization codes or test emails into issues or logs either.

**Apple (iOS).**
- Works in the iOS Simulator once the simulator is signed in to the test Apple ID (Settings),
  and on a device signed in to it.
- Apple shows the first-sign-in sheet (name, and Share or Hide My Email) only the first time an
  Apple ID authorises Muse; later sign-ins send no name. To see it again, remove Muse from that
  Apple ID's Sign in with Apple list: on the device, Settings, then the Apple ID name, Sign-In &
  Security, Sign in with Apple, Muse, Stop Using (menu names move between iOS versions), or at
  account.apple.com. Deleting the account in the app also revokes Muse's Apple tokens, which
  does the same.
- After you remove Muse there, the next launch signs the user out: `AuthLoadingScreen` finds the
  Apple credential revoked.

**Google on Android: register your debug fingerprint.** Google checks the app's signing
certificate. A local debug build is signed with your machine's debug keystore
(`~/.android/debug.keystore`), so its SHA-1 and SHA-256 must be on the Android app
(`com.eros.eros_app`) in the Firebase project, or test on a machine whose key is registered.
Print them with Gradle's signing report. `android/gradlew` is gitignored: one Android build
(`flutter build apk --debug`, or `flutter run` on an Android device) creates it.

```bash
cd android && ./gradlew signingReport
```

Take the `debug` variant's SHA-1 and SHA-256 and add them in the Firebase console: Project
settings, Your apps, the Android app, Add fingerprint (ask a project admin if you can't). A missing
fingerprint is the usual reason Google sign-in works on one machine and not another, and the
reason a Play build fails if the Play App Signing key isn't registered (`ApiException: 10`).
Google on iOS needs no fingerprint.

**Deleting a test account.** Delete account soft-deletes the profile but leaves the Firebase
user (the backend erases it 30 days later), so signing in again with the same test account shows
"This account was deleted". To start a fresh sign-up, use another test account or ask the
backend team to restore or clear it.

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
