/// Persistence tests against a real (in-memory) drift database:
/// versioned JSON rows, active-workout pointer, settings.
library;
import 'dart:async';
import 'dart:convert';

import 'package:coach_loop_flutter/data/app_database.dart';
import 'package:coach_loop_flutter/data/workout_repository.dart';
import 'package:coach_loop_flutter/domain/training_types.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftWorkoutRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftWorkoutRepository(db);
  });

  tearDown(() async {
    await repo.close();
  });

  test('starts empty', () async {
    final log = await repo.watchLog().first;
    expect(log.workouts, isEmpty);
    expect(log.activeWorkout, isNull);
  });

  test('persists workouts as versioned JSON rows', () async {
    final workout = makeWorkout(Unit.lb, name: 'Push day');
    await repo.saveWorkout(workout);

    final log = await repo.watchLog().first;
    expect(log.workouts.single.name, 'Push day');

    // The stored payload is tagged with the schema version.
    final row = await (db.select(db.workouts)).getSingle();
    final payload = jsonDecode(row.payload) as Map<String, dynamic>;
    expect(payload['schema'], workoutSchemaVersion);
    expect((payload['workout'] as Map)['name'], 'Push day');
  });

  test('saveWorkout upserts by id', () async {
    final workout = makeWorkout(Unit.lb, name: 'Old name');
    await repo.saveWorkout(workout);
    await repo.saveWorkout(workout.copyWith(name: 'New name'));

    final log = await repo.watchLog().first;
    expect(log.workouts.length, 1);
    expect(log.workouts.single.name, 'New name');
  });

  test('active workout pointer round-trips through settings', () async {
    final workout = makeWorkout(Unit.lb);
    await repo.saveWorkout(workout);
    await repo.saveActiveWorkoutId(workout.id);

    final log = await repo.watchLog().first;
    expect(log.activeWorkoutId, workout.id);
    expect(log.activeWorkout?.id, workout.id);

    // Finishing clears the pointer; the finished session is no longer active.
    await repo.saveWorkout(workout.copyWith(
      status: WorkoutStatus.completed,
      completedAt: DateTime.now().toIso8601String(),
    ));
    await repo.saveActiveWorkoutId(null);
    final cleared = await repo.watchLog().first;
    expect(cleared.activeWorkout, isNull);
  });

  test('removeWorkout deletes the row', () async {
    final workout = makeWorkout(Unit.lb);
    await repo.saveWorkout(workout);
    await repo.removeWorkout(workout.id);

    final log = await repo.watchLog().first;
    expect(log.workouts, isEmpty);
  });

  test('settings persist as key/value pairs', () async {
    await repo.saveSetting('notificationsEnabled', 'true');
    expect(await repo.loadSettings(), {'notificationsEnabled': 'true'});
  });

  test('watchLog emits on every change', () async {
    final emissions = <int>[];
    final initialArrived = Completer<void>();
    final sub = repo.watchLog().listen((log) {
      emissions.add(log.workouts.length);
      if (!initialArrived.isCompleted) initialArrived.complete();
    });
    // Wait for the initial emission before mutating: the first read is
    // async, so saving immediately could win the race legitimately.
    await initialArrived.future;
    await repo.saveWorkout(makeWorkout(Unit.lb));
    await repo.saveWorkout(makeWorkout(Unit.lb));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(emissions, [0, 1, 2]);
  });
}
