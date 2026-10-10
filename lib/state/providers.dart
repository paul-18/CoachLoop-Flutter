/// Riverpod providers and workout actions.
///
/// State shape is deliberately small: the repository owns the [WorkoutLog],
/// screens watch it as a stream, and all mutations go through
/// [WorkoutController] so the domain transition rules stay in one place.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/workout_repository.dart';
import '../domain/completion.dart';
import '../domain/notifications.dart';
import '../domain/training_types.dart';
import '../domain/workout_transitions.dart';
import '../domain/workout_transitions.dart' as transitions;
import '../services/wake_lock.dart';

// ---------------------------------------------------------------------------
// Infrastructure (overridden in main() and tests)
// ---------------------------------------------------------------------------

final databaseProvider = Provider<AppDatabase>(
  (_) => throw UnimplementedError('databaseProvider must be overridden'),
);

final repositoryProvider = Provider<WorkoutRepository>(
  (_) => throw UnimplementedError('repositoryProvider must be overridden'),
);

final notificationServiceProvider = Provider<NotificationService>(
  (_) => throw UnimplementedError('notificationServiceProvider must be overridden'),
);

final wakeLockProvider = Provider<WakeLock>((_) => const NoopWakeLock());

// ---------------------------------------------------------------------------
// Derived state
// ---------------------------------------------------------------------------

/// The live training log.
final workoutLogProvider = StreamProvider<WorkoutLog>(
  (ref) => ref.watch(repositoryProvider).watchLog(),
);

/// Raw key/value settings map.
final settingsProvider = FutureProvider<Map<String, String>>(
  (ref) => ref.watch(repositoryProvider).loadSettings(),
);

/// Whether the notifications setting is on.
final notificationsEnabledProvider = FutureProvider<bool>((ref) async {
  final settings = await ref.watch(settingsProvider.future);
  return settings['notificationsEnabled'] == 'true';
});

/// Tracks whether the app is in the foreground (resumed). The rest timer
/// only fires a notification when this is false.
class AppVisibility extends Notifier<bool> {
  @override
  bool build() => true;

  void setVisible(bool visible) {
    if (state != visible) state = visible;
  }
}

final appVisibilityProvider = NotifierProvider<AppVisibility, bool>(AppVisibility.new);

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

/// All workout mutations. Errors from domain rules (e.g. starting a second
/// workout) surface as [StateError]; callers show them to the user.
class WorkoutController extends Notifier<AsyncValue<WorkoutLog>> {
  WorkoutRepository get _repo => ref.read(repositoryProvider);

  @override
  AsyncValue<WorkoutLog> build() => ref.watch(workoutLogProvider);

  WorkoutLog? get _log => state.value;

  Future<void> startWorkout({String? name}) async {
    final log = _log;
    if (log == null) return;
    final clean = (name ?? '').trim();
    final workout = makeWorkout(Unit.lb, name: clean.isEmpty ? 'Training session' : clean);
    final next = transitions.startWorkout(log, workout);
    final started = next.workouts.firstWhere((w) => w.id == workout.id);
    await _repo.saveWorkout(started);
    await _repo.saveActiveWorkoutId(started.id);
  }

  /// Replace a workout row wholesale (set edits, exercise edits, …).
  Future<void> saveWorkout(WorkoutSession workout) => _repo.saveWorkout(workout);

  Future<void> finishWorkout(String id) async {
    final log = _log;
    if (log == null) return;
    final next = transitions.finishWorkout(log, id);
    final finished = next.workouts.firstWhere((w) => w.id == id);
    await _repo.saveWorkout(finished);
    await _repo.saveActiveWorkoutId(next.activeWorkoutId);
  }

  Future<void> discardWorkout(String id) async {
    final log = _log;
    if (log == null) return;
    final next = transitions.discardWorkout(log, id);
    await _repo.removeWorkout(id);
    await _repo.saveActiveWorkoutId(next.activeWorkoutId);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _repo.saveSetting('notificationsEnabled', enabled ? 'true' : 'false');
    ref.invalidate(settingsProvider);
  }
}

final workoutControllerProvider =
    NotifierProvider<WorkoutController, AsyncValue<WorkoutLog>>(WorkoutController.new);

/// Build the updated workout after completing a set, and report how many
/// rest seconds to start (0 = no timer: warm-up sets and zero rest don't
/// start one). Throws [SetCompletionException] when invalid.
({WorkoutSession workout, int restSec}) withCompletedSet(
  WorkoutSession workout,
  String exerciseId,
  String setId,
) {
  final exercises = workout.exercises.map((exercise) {
    if (exercise.id != exerciseId) return exercise;
    final sets = exercise.sets.map((set) {
      if (set.id != setId) return set;
      final values = completedSetValues(set);
      return set.copyWith(
        actualReps: values.actualReps,
        actualWeight: values.actualWeight,
        clearActualWeight: values.actualWeight == null,
        completed: true,
        completedAsPlanned: values.completedAsPlanned,
      );
    }).toList();
    return exercise.copyWith(sets: sets);
  }).toList();
  final exercise = workout.exercises.firstWhere((e) => e.id == exerciseId);
  final set = exercise.sets.firstWhere((s) => s.id == setId);
  final restSec = (!set.warmup && exercise.restSec > 0) ? exercise.restSec : 0;
  return (workout: workout.copyWith(exercises: exercises), restSec: restSec);
}
