/// Repository over the local database. All workout mutations funnel through
/// here so the domain transition rules in [workout_transitions.dart] are the
/// single source of truth and every write is a full, durable row replace.
///
/// An in-memory implementation backs widget tests so they never touch disk.
library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/training_types.dart';
import '../domain/workout_transitions.dart';
import 'app_database.dart';

/// Version tag inside each stored payload; bump only with a real migration.
const int workoutSchemaVersion = 1;

abstract class WorkoutRepository {
  /// Live log; emits the current state immediately, then on every change.
  Stream<WorkoutLog> watchLog();

  /// Replace one workout row (insert or update), then emit.
  Future<void> saveWorkout(WorkoutSession workout);

  /// Permanently remove a workout row, then emit.
  Future<void> removeWorkout(String id);

  /// Remember which workout is active (null when none).
  Future<void> saveActiveWorkoutId(String? id);

  /// Key/value app settings (e.g. `notificationsEnabled`).
  Future<Map<String, String>> loadSettings();
  Future<void> saveSetting(String key, String value);
}

String _encode(WorkoutSession workout) => jsonEncode({
      'schema': workoutSchemaVersion,
      'workout': workout.toJson(),
    });

WorkoutSession _decode(String payload) {
  final map = jsonDecode(payload) as Map<String, dynamic>;
  return WorkoutSession.fromJson(Map<String, dynamic>.from(map['workout'] as Map));
}

class DriftWorkoutRepository implements WorkoutRepository {
  DriftWorkoutRepository(this._db);

  final AppDatabase _db;
  final _controller = StreamController<WorkoutLog>.broadcast();

  Future<void> _emit() async {
    if (!_controller.isClosed) _controller.add(await _readLog());
  }

  Future<WorkoutLog> _readLog() async {
    final rows = await (_db.select(_db.workouts)
          ..orderBy([(t) => OrderingTerm.desc(t.date), (t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    final settings = await loadSettings();
    return WorkoutLog(
      workouts: rows.map((r) => _decode(r.payload)).toList(),
      activeWorkoutId: settings['activeWorkoutId'],
    );
  }

  @override
  Stream<WorkoutLog> watchLog() async* {
    yield await _readLog();
    yield* _controller.stream;
  }

  @override
  Future<void> saveWorkout(WorkoutSession workout) async {
    await _db.into(_db.workouts).insertOnConflictUpdate(
          WorkoutsCompanion(
            id: Value(workout.id),
            payload: Value(_encode(workout)),
            status: Value(workout.status.name),
            date: Value(workout.date),
            updatedAt: Value(workout.updatedAt),
          ),
        );
    await _emit();
  }

  @override
  Future<void> removeWorkout(String id) async {
    await (_db.delete(_db.workouts)..where((t) => t.id.equals(id))).go();
    await _emit();
  }

  @override
  Future<Map<String, String>> loadSettings() async {
    final rows = await _db.select(_db.settings).get();
    return {for (final r in rows) r.key: r.value};
  }

  @override
  Future<void> saveSetting(String key, String value) async {
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion(key: Value(key), value: Value(value)),
        );
  }

  /// Persist the active-workout pointer (kept in settings, like the PWA).
  @override
  Future<void> saveActiveWorkoutId(String? id) async {
    if (id == null) {
      await (_db.delete(_db.settings)..where((t) => t.key.equals('activeWorkoutId'))).go();
    } else {
      await saveSetting('activeWorkoutId', id);
    }
  }

  Future<void> close() async {
    await _controller.close();
    await _db.close();
  }
}

/// In-memory repository for widget tests. Same contract, no disk.
class InMemoryWorkoutRepository implements WorkoutRepository {
  final _controller = StreamController<WorkoutLog>.broadcast();
  var _log = const WorkoutLog();
  final _settings = <String, String>{};

  Future<void> _emit() async {
    if (!_controller.isClosed) _controller.add(_log);
  }

  @override
  Stream<WorkoutLog> watchLog() async* {
    yield _log;
    yield* _controller.stream;
  }

  @override
  Future<void> saveWorkout(WorkoutSession workout) async {
    final workouts = _log.workouts.map((w) => w.id == workout.id ? workout : w).toList();
    if (!workouts.any((w) => w.id == workout.id)) workouts.insert(0, workout);
    _log = _log.copyWith(workouts: workouts);
    await _emit();
  }

  @override
  Future<void> removeWorkout(String id) async {
    _log = _log.copyWith(workouts: _log.workouts.where((w) => w.id != id).toList());
    await _emit();
  }

  @override
  /// Test helper: remember the active workout id.
  @override
  Future<void> saveActiveWorkoutId(String? id) async {
    _log = _log.copyWith(activeWorkoutId: id, clearActive: id == null);
    await _emit();
  }

  @override
  Future<Map<String, String>> loadSettings() async => Map.of(_settings);

  @override
  Future<void> saveSetting(String key, String value) async {
    _settings[key] = value;
  }

  /// Test helper: replace the whole log (applies a transition result).
  Future<void> applyLog(WorkoutLog log) async {
    _log = log;
    await _emit();
  }

  Future<void> dispose() => _controller.close();
}
