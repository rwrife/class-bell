# Class Bell

**Pitch:** A local-first classroom companion for teachers: an offline visual timer, random name picker, quiet signal, and positive praise tallies that run on a classroom PC, tablet, or phone — no accounts, no cloud, no student data upload.

Class Bell is a Flutter app (Windows + Android + iOS from one codebase) that replaces the handful of tiny web tools and apps primary/middle-school teachers juggle during class — the visual timer site, the "spin the wheel" picker, the praise-points board — with one calm, offline, projector-friendly tool.

## Motivation

Teachers routinely open ad-hoc websites for a countdown timer, a random name picker, or a class-points chart. Those sites are ad-laden, need internet, often require accounts, and some make teachers enter student names into a third-party service. Schools increasingly forbid uploading student data to unvetted web apps. Class Bell keeps everything on the device: it works on the plane, on a district-filtered network, and never phones home.

## Target users

- Primary and middle-school classroom teachers (K–8) running a class from a Windows laptop + projector, an Android/Windows tablet, or a phone.
- Homeschool families and after-school/camp program leaders with the same needs.

## Concrete use cases

1. **Writing block:** teacher starts a 12-minute visual timer on the classroom PC; the whole class sees a big, dimmable countdown ring; a gentle chime ends the block.
2. **Cold calling:** teacher taps the picker; it chooses fairly from the class roster (no-repeat-until-everyone-has-had-a-turn mode), shown large on the projector.
3. **Positive behavior:** teacher and class track per-group or whole-class praise tallies toward a shared class goal (e.g., 50 points → movie afternoon).
4. **Transitions:** one-tap "quiet signal" full-screen cue with optional soft sound; timed transitions between subjects.

## How to use (intended workflow)

1. Create one or more classes locally (name + first-name-only roster; no last names, emails, photos, or other PII required or encouraged).
2. Before class, set up the lesson board: choose timer presets, the active class for the picker, and the praise goal.
3. During class, run the four tools from a single projector-friendly big-screen mode; exit with a teacher lock (configurable key combo / long-press) so students at the front can't change settings.
4. After class, review simple session history (praise counts, focus minutes) and export everything to CSV/JSON.

## MVP features

- Class rosters stored on-device (first names, avatars/initials only).
- Visual timer: big countdown ring, presets, pause/skip, end chime, dim mode for projector use.
- Random picker: no-repeat fair rotation, option to exclude students, big-result presentation.
- Praise board: whole-class and per-group tallies toward a goal, simple per-session reset.
- Quiet signal: full-screen visual + optional soft audio cue.
- Big-screen projector mode + keyboard shortcuts (space = start/pause, n = next pick, +/- = points).
- Session history (praise counts, focus minutes) with CSV/JSON export and local backup.
- Adaptive per-platform look (see PLAN.md): Fluent on Windows, Material 3 on Android, Cupertino on iOS.

## Non-goals

- No accounts, cloud sync, teacher/student logins, or school-information-system integrations.
- No student last names, photos, grades, attendance records, or behavioral discipline records — this is explicitly not a classroom-management/discipline system and stores no student PII by design.
- No gamified per-student reward profiles, leaderboards ranking individual children, or any feature that shames students publicly.
- Not built with React Native, Expo, Kotlin Multiplatform, .NET MAUI, or native Swift — new apps in this lab are Flutter only.
- Not a lesson-planning, grading, or communication-with-parents tool.

## Privacy, permissions, and data storage

- 100% offline. The app makes no network requests; no analytics, no ads, no trackers.
- All data (rosters, presets, tallies, history) lives in a local database on the device with OS-level protection; export is user-initiated (CSV/JSON) and import restores a user-chosen backup.
- Rosters are intended to be first-name-only; the app never requires or requests contacts, camera, microphone, or location permissions. Only optional notifications (timer end) and haptics are requested, both optional.
- Uninstall or "delete all data" removes everything; nothing is recoverable by the developer (there is no backend).

## Identifiers

App identifier across all platforms: `com.infinityball.classbell` (Android applicationId, iOS bundle identifier, Windows/MSIX identity where applicable).
App Store Connect bundle ID status: **CREATED com.infinityball.classbell** (registered 2026-10-16 via ASC API).

## Current status

Flutter app and local-first classroom tools are implemented. Milestones:

1. Flutter workspace (windows/android/ios enabled) + CI (Windows primary build/test). ✅
2. Domain layer: rosters, timer engine, fair picker, praise tallies (pure Dart + tests). ✅
3. Adaptive UI shell + the four tools on phone/tablet/desktop. ✅
4. Big-screen mode, keyboard shortcuts, session history. ✅
5. Export/backup/restore + privacy controls. ✅
6. Windows release build on `v*` tags via `.github/workflows/release.yml`; mobile builds keep compiling; store submission is a later opt-in milestone. ✅ (workflow + icon wiring; store submission deferred)

Icon assets come from `AppStore/icon.png`; regenerate everything after an artwork change with `uv run --with pillow python tool/wire_icons.py`. Manual projector and screen-reader checks remain pending; no fake device results.

## Development quickstart

Flutter stable (pin recorded in `toolchain.json`). The development host for this lab is arm64 Linux, where the official Flutter SDK is unsupported; workspace generation and builds run in CI/Docker images (see PLAN.md).

```sh
flutter create --org com.infinityball --project-name class_bell --platforms windows,android,ios .
flutter pub get
flutter test
flutter build windows --release   # primary CI/release target
flutter build apk --debug         # must keep compiling (Linux/Docker CI)
```

License: MIT.
