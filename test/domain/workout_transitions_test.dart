/// Lifecycle transition tests: one active workout at a time, finish stamps,
/// discard removes.
library;
import 'package:coach_loop_flutter/domain/training_types.dart';
import 'package:coach_loop_flutter/domain/workout_transitions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('startWorkout', () {
    test('activates a workout and records it', () {
      const log = WorkoutLog();
      final next = startWorkout(log, makeWorkout(Unit.lb, name: 'Push'));
      expect(next.activeWorkoutId, isNotNull);
      expect(next.activeWorkout?.name, 'Push');
      expect(next.activeWorkout?.status, WorkoutStatus.active);
    });

    test('refuses a second active workout', () {
      final log = startWorkout(const WorkoutLog(), makeWorkout(Unit.lb));
      expect(
        () => startWorkout(log, makeWorkout(Unit.lb)),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('finishWorkout', () {
    test('marks completed with a timestamp and clears active', () {
      var log = startWorkout(const WorkoutLog(), makeWorkout(Unit.lb, name: 'Pull'));
      final id = log.activeWorkoutId!;
      log = finishWorkout(log, id);
      expect(log.activeWorkout, isNull);
      final done = log.workouts.firstWhere((w) => w.id == id);
      expect(done.status, WorkoutStatus.completed);
      expect(done.completedAt, isNotNull);
      expect(log.completedWorkouts.single.id, id);
    });

    test('throws for an unknown workout', () {
      expect(() => finishWorkout(const WorkoutLog(), 'nope'), throwsA(isA<StateError>()));
    });
  });

  group('discardWorkout', () {
    test('removes the active workout', () {
      var log = startWorkout(const WorkoutLog(), makeWorkout(Unit.lb));
      final id = log.activeWorkoutId!;
      log = discardWorkout(log, id);
      expect(log.workouts, isEmpty);
      expect(log.activeWorkout, isNull);
    });

    test('refuses to discard a completed workout', () {
      var log = startWorkout(const WorkoutLog(), makeWorkout(Unit.lb));
      final id = log.activeWorkoutId!;
      log = finishWorkout(log, id);
      expect(() => discardWorkout(log, id), throwsA(isA<StateError>()));
    });
  });

  group('WorkoutLog', () {
    test('completedWorkouts sorts newest first', () {
      final a = makeWorkout(Unit.lb, name: 'A').copyWith(
        date: '2026-10-01',
        status: WorkoutStatus.completed,
        completedAt: '2026-10-01T10:00:00',
      );
      final b = makeWorkout(Unit.lb, name: 'B').copyWith(
        date: '2026-10-08',
        status: WorkoutStatus.completed,
        completedAt: '2026-10-08T10:00:00',
      );
      final log = WorkoutLog(workouts: [a, b]);
      expect(log.completedWorkouts.map((w) => w.name).toList(), ['B', 'A']);
    });
  });
}
