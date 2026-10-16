# Class Bell — implementation plan

## Scope and architecture

Flutter stable app, one codebase for Windows (primary), Android, and iOS; phone, tablet (iPad + Android tablet), and resizable desktop windows. Keep pure Dart domain under `lib/domain/` (roster, fair draw bag, timer state, points/session). App shell and platform widgets under `lib/ui/`; one small adaptive-widget seam for all screens. Persistence is local (SQLite via an existing Flutter dependency if needed), no network stack. Export/import via user-selected files, no background sync. `com.infinityball.classbell` is Android applicationId, iOS bundle identifier, and Windows/MSIX identity where applicable. ASC status: CREATED 2026-10-16.

## Platform-authentic UX strategy: A — platform-native adaptive

This teacher utility must feel native on each OS: Cupertino widgets/navigation/action sheets on iOS and iPadOS; Material 3/dynamic color/back handling on Android; Fluent title bar, NavigationView, keyboard shortcuts, hover and context menus on Windows (`fluent_ui`). Screens share state and layout, not button chrome: `AdaptiveScaffold`, `AdaptiveButton`, `AdaptiveDialog` wrappers at the boundary, with golden/widget tests at `TargetPlatform.iOS`, `TargetPlatform.android`, and `TargetPlatform.windows`. On Windows show a persistent sidebar + content grid + command bar, never a stretched phone UI; on tablet show sidebar and board side by side; on phone use platform-specific bottom/tab navigation. Keyboard/mouse and touch equal-class inputs. Respect native text selection, scrolling, file picker, focus order, back/escape, dialogs, notifications, haptics, screen reader and reduced motion. Fonts scale without clipping. Minimum viewport tests: 360×640, 800×1100, 1280×720.

## Product contract

Roster fields: display name (first name or alias), optional initials, class/group association. Do not collect last name, email, grade, photo, or behavioral incidents. A fair picker shuffles an eligible snapshot, draws without replacement until empty, and never silently skips or duplicates; roster/exclusion changes invalidate next draw bag with clear user feedback. Scores record only group/whole-class praise; no individual child rankings. Timers use monotonic elapsed time so sleep/background/resume does not gain minutes. End chime never depends on Internet. Restore requires explicit confirmation before overwriting local data. Exports contain no hidden metadata and remain readable outside app. Delete-all clears local DB and any cached exports owned by app, not user-created export files.

## Milestones and dependency order

1. Generate Flutter workspace with windows/android/ios folders. Pin stable SDK in `toolchain.json`; windows-latest CI runs `flutter test`, widget/golden tests, `flutter build windows --release`. Linux/Docker CI runs analysis, tests, `flutter build apk --debug`; macOS iOS compile lane later. CI produces actual logs.
2. Pure-Dart domain + unit tests (roster, fair draw, timer state, praise goals/session reset), no platform dependency.
3. Platform-native adaptive shell + roster editor + timer, picker, praise board, quiet cue screens. All key screens have per-platform golden/widget tests and minimum-width layout checks.
4. Persistence, session history, projector mode, keyboard shortcuts, accessibility pass.
5. CSV/JSON export + import/backup and delete-all controls, round-trip tests and privacy audit.
6. Generate/wire `AppStore/icon.png` into Windows `.ico` resource and Android/iOS launchers; update `AppStore/description.txt` to reflect implemented features. Windows release workflow on `v*` tags/manual dispatch.

## Testing

- Unit tests for draw bag fairness under deterministic seed, all/none eligible, invalidation on roster changes, timer background resume, points goal/reset, and export/import round trip.
- Widget/golden tests with `TargetPlatform.iOS`, `TargetPlatform.android`, `TargetPlatform.windows` proving correct native chrome, focus, navigation, screen reader labels, and responsive layouts at phone/tablet/desktop sizes.
- Windows CI: `flutter test` + `flutter build windows --release`. Linux Docker CI: `flutter analyze`, `flutter test`, `flutter build apk --debug`. iOS simulator compile later on macOS. Host-side arm64 Linux Docker cannot run amd64-only Flutter artifacts; CI provides x64 proof.
- Manual classroom projector and screen-reader checks remain PENDING until performed; no fake device results.

## Packaging and distribution

- `.github/workflows/release.yml`: `v*` tag or manual dispatch, Windows `windows-latest` build + tests, zip portable build (`build/windows/x64/runner/Release`), attach to GitHub release. MSIX optional later.
- Android/iOS (including tablets) remain supported/compiling from same codebase, store submission later milestone. Android Play signing and iOS TestFlight via `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `ASC_TEAM_ID` are NOT MVP upload gates; never log secret values. `com.infinityball.classbell` is permanent identifier.
- Icon generated by OpenAI Images API via `spark-media`: `AppStore/icon.png`, 1024×1024 RGB, model `gpt-image-2.5-flare`, generated 2026-10-16; actual artwork committed. Wiring is issue work, not yet done.

## Risks and non-goals

- FERPA/school policy varies: no claim of certification. First-name rosters still may be sensitive; encourage aliases and school-approved devices, do not upload data. No accounts, cloud, behavioral discipline, grades, parent messaging, or student analytics. No React Native, Expo, Kotlin Multiplatform, .NET MAUI, or native Swift project. Build against current Flutter stable; no arbitrary unpinned dependency upgrades. No OS-platform impersonation (Material on iOS, Cupertino on Android, phone layout on desktop).
