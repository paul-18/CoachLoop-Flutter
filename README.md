# Coach Loop Flutter — Phase 1

An experimental second app: a native Flutter port of the Coach Loop training log.
**Local-only by design** — no accounts, no cloud sync, no backend. All data stays on
your device, same as the PWA.

> The original PWA (React/TypeScript) is untouched. This is a separate experiment.

## What's in Phase 1

- **Workout tab**: start a named workout, add exercises, log sets with planned vs.
  actual reps / load / RPE, load-type picker (total, each hand, added, bodyweight,
  unrecorded), warm-up and skip toggles, editable rest seconds per exercise.
- **Rest timer**: tick-driven countdown that starts when you complete a set; stays
  visible above the list. When it ends while the app is backgrounded, a **silent**
  local notification ("Rest over" + next exercise) appears — only if you've opted in.
- **History tab**: list of finished workouts with set counts; tap for detail
  (warm-ups marked, skipped sets dimmed and struck through).
- **Settings**: notification opt-in with honest status (unsupported / denied / off / on).
  Permission is requested from the toggle tap, as iOS requires.
- **Persistence**: drift/SQLite on-device database; workouts stored as versioned
  JSON rows (schema v1). Wake lock stays on during an active workout.
- **Truth rules** (ported from the PWA): prescriptions are never treated as results,
  unspecified loads/reps stay unspecified, warm-ups and skipped sets are excluded
  from working metrics, volume is load × reps (lb·reps / kg·reps). No sample data —
  empty states show guidance instead.

## Not yet (planned for Phase 2)

FITLOG import, coach brief builder, progress charts/trends, body measurements,
backup/restore, themes, cardio types.

## Run it

Prerequisite: [install Flutter](https://docs.flutter.dev/get-started/install)
(stable channel), then:

```sh
cd coach-loop-flutter
flutter pub get
flutter run -d chrome        # try it in a browser
flutter run                  # on a connected phone / simulator
```

## On your iPhone (Mac required)

```sh
flutter devices               # confirm your iPhone is listed (USB, unlocked, trusted)
flutter run                   # installs a debug build via Xcode
```

For a release install file later: `flutter build ipa` (needs Xcode signing set up;
App Store distribution needs the Apple Developer Program).

## Verify it

```sh
flutter analyze              # static analysis — currently zero issues
flutter test                 # 44 tests — currently all passing
flutter build web --release  # verified artifact (output in build/web/)
```

After changing anything under `lib/data/`, regenerate the database code first:

```sh
dart run build_runner build
```

## Project layout

```
lib/
  domain/      TrainingSet / ExerciseBlock / WorkoutSession, completion rules,
               volume math — the ported product rules. All mutations funnel here.
  data/        drift database + WorkoutRepository (SQLite; versioned JSON rows).
  state/       Riverpod providers; WorkoutController owns every state change.
  ui/          screens: workout (editor + rest timer), history, settings.
  services/    notifications (flutter_local_notifications), wake lock.
test/
  domain/      completion rules, volume math, lifecycle.
  data/        repository against real in-memory SQLite.
  widget/      full flow: start → log set → finish → History; rest-notification
               behavior (only when the app is hidden).
```

## Notes

- Bundle ID: `com.coachloop.coach_loop_flutter` — change it in the Xcode/Gradle
  project files if you want your own before any store submission.
- Web notifications use the service worker for tap-to-return; on mobile the
  notification channel is configured silent (no sound, no vibration).
