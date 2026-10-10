/// Workout lifecycle transitions, as pure functions.
///
/// Ported from the PWA's `app/domain/workout-transitions.ts`. Only one
/// workout may be active at a time; finishing stamps `completedAt` and
/// discarding removes the session. [WorkoutLog] is the small in-memory
/// shape the repository persists.
library;

import 'training_types.dart';

/// The whole log the repository owns: sessions plus which one is active.
class WorkoutLog {
  const WorkoutLog({this.workouts = const [], this.activeWorkoutId});

  final List<WorkoutSession> workouts;
  final String? activeWorkoutId;

  /// The unfinished session, preferring the recorded active id.
  WorkoutSession? get activeWorkout {
    for (final w in workouts) {
      if (w.status == WorkoutStatus.active && w.id == activeWorkoutId) return w;
    }
    for (final w in workouts) {
      if (w.status == WorkoutStatus.active) return w;
    }
    return null;
  }

  /// Finished sessions, newest first.
  List<WorkoutSession> get completedWorkouts {
    final done = workouts.where((w) => w.status == WorkoutStatus.completed).toList();
    done.sort((a, b) => b.date.compareTo(a.date));
    return done;
  }

  WorkoutLog copyWith({List<WorkoutSession>? workouts, String? activeWorkoutId, bool clearActive = false}) =>
      WorkoutLog(
        workouts: workouts ?? this.workouts,
        activeWorkoutId: clearActive ? null : (activeWorkoutId ?? this.activeWorkoutId),
      );
}

/// Start (or resume) a workout. Throws [StateError] if another workout is
/// already active.
WorkoutLog startWorkout(WorkoutLog log, WorkoutSession workout, {DateTime? now}) {
  final timestamp = (now ?? DateTime.now()).toIso8601String();
  if (log.workouts.any((w) => w.status == WorkoutStatus.active && w.id != workout.id)) {
    throw StateError('Finish or discard the active workout first');
  }
  final active = workout.copyWith(
    status: WorkoutStatus.active,
    startedAt: workout.startedAt ?? timestamp,
    clearCompletedAt: true,
  );
  final exists = log.workouts.any((w) => w.id == active.id);
  final workouts = exists
      ? log.workouts.map((w) => w.id == active.id ? active : w).toList()
      : [active, ...log.workouts];
  return log.copyWith(workouts: workouts, activeWorkoutId: active.id);
}

/// Finish a workout: stamp it completed. Throws [StateError] when the
/// workout isn't in the log.
WorkoutLog finishWorkout(WorkoutLog log, String id, {DateTime? now}) {
  final timestamp = (now ?? DateTime.now()).toIso8601String();
  if (!log.workouts.any((w) => w.id == id)) {
    throw StateError('This workout is no longer in the log');
  }
  final workouts = log.workouts
      .map((w) => w.id == id
          ? w.copyWith(
              status: WorkoutStatus.completed,
              completedAt: w.completedAt ?? timestamp,
            )
          : w)
      .toList();
  final next = log.copyWith(workouts: workouts);
  return next.copyWith(activeWorkoutId: next.activeWorkout?.id, clearActive: next.activeWorkout == null);
}

/// Discard an unfinished workout, removing it. Throws [StateError] unless
/// the workout is active.
WorkoutLog discardWorkout(WorkoutLog log, String id) {
  if (!log.workouts.any((w) => w.id == id && w.status == WorkoutStatus.active)) {
    throw StateError('Only an unfinished workout can be discarded');
  }
  final workouts = log.workouts.where((w) => w.id != id).toList();
  final next = log.copyWith(workouts: workouts);
  return next.copyWith(activeWorkoutId: next.activeWorkout?.id, clearActive: next.activeWorkout == null);
}
