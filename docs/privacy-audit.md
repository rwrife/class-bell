# Class Bell privacy audit

Contract source: `README.md` ("Privacy, permissions, and data storage") and
`PLAN.md` ("Product contract"). This audit is the issue #5/#6 deliverable that
those acceptance criteria reference. Re-run it whenever a platform manifest,
plugin, or dependency changes.

## Measured permission inventory (2026-10-24, commit 85908c9 + issue #6 work)

| Platform | Manifest / source | Network permission | Other permissions |
|---|---|---|---|
| Android (release) | `android/app/src/main/AndroidManifest.xml` | none declared | none declared |
| Android (debug) | `android/app/src/debug/AndroidManifest.xml` | `INTERNET` — Flutter hot-reload/VM service, debug build type only | none |
| Android (profile) | `android/app/src/profile/AndroidManifest.xml` | `INTERNET` — Flutter profiling tooling, profile build type only | none |
| iOS | `ios/Runner/Info.plist` | no `NSAppTransportSecurity` relaxation, no usage-description keys | none |
| Windows | `windows/runner/*`, `windows/runner/runner.exe.manifest` | none; no MSIX package manifest, so no app-capability declarations (`internetClient` absent) | none |

Release APK check before distribution: inspect `aapt2 dump permissions` /
merged manifest of the **release** build and confirm it does not list
`android.permission.INTERNET`. Source manifests alone do not prove the merged
plugin permissions; this check remains PENDING until a release build runs.
The debug and profile manifests are standard Flutter tooling artifacts and
are excluded from release builds.

## No network code path

- `grep -rn "dart:io\|Socket\|HttpClient\|http\|url_launcher\|connectivity" lib/` finds only
  `dart:io` `File`/`Platform` usage inside `lib/backup/portable_backup.dart` for the
  user-chosen export/backup file the teacher explicitly picked in a native dialog.
- Dependencies (`pubspec.yaml`): `flutter`, `fluent_ui`, `cupertino_icons`, `audioplayers`
  (bundled local `assets/audio/chime.wav` only), `file_picker`, `sqlite3`.
  No analytics, crash reporting, ad, or telemetry SDK is present.
- The end-of-timer chime and quiet-signal cue are bundled assets; no asset is fetched.

## Data model guarantees

- `lib/domain/roster.dart`: a student is `displayName` (first name or alias),
  optional `initials`, optional `group`, `isExcluded`. No last name, email, photo,
  grade, attendance, or behavioral/discipline field exists in the schema.
- `lib/repository/`: history stores **aggregate day totals only**
  (`day_totals(day, praise_points, focus_seconds)`). No student identifier crosses
  the history boundary; there is no per-child score or streak anywhere.
- Praise tallies are whole-class or group level (`lib/domain/praise.dart`).

## Export and backup contents

- CSV exports (`rosterCsv`, `historyCsv` in `lib/backup/portable_backup.dart`)
  contain the columns shown in the header row and nothing else. No timestamps,
  device identifiers, or hidden metadata fields are added.
- The JSON backup is `format`, `schemaVersion`, rosters, selected class, settings,
  saved praise tallies, and day totals. `schemaVersion` exists so a restore can
  refuse an unknown or newer file instead of writing nonsense into the database.
- Files are written only where the teacher's native save dialog says so; the app
  keeps no shadow copy.

## Delete-all semantics

- `SqliteBellRepository.clearAll()` deletes every row of `state` and
  `day_totals` in one transaction. Schema and `userVersion` stay — an empty table
  holds no classroom data — so reopening after delete-all is provably the same
  empty state as a first run (covered by `test/backup/backup_roundtrip_test.dart`).
- App-owned caches cleared: the file picker's temporary copies inside the app
  sandbox (`FilePicker.platform.clearTemporaryFiles()`; desktop implements no
  picker cache, so there is nothing to clear there).
- User-created export files are **never** traversed or deleted: delete-all takes
  no path arguments at all, it only clears the local database and the picker
  sandbox.

## Remaining before store submission (not MVP-blocking)

- Optional timer-end notification permission, if local notifications are ever
  added, must stay opt-in and be added to this table first.
- Manual device-level checks (permission inspector screenshots on a real
  Android device, iOS privacy manifest review) are PENDING — no fake device
  results are claimed here.
