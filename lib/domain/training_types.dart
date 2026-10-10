/// Core training model for Coach Loop (Flutter).
///
/// This mirrors the PWA's `app/domain/training-types.ts`. The hard product
/// rules live here and in [completion.dart] / [training_metrics.dart]:
///
/// * A set's *prescription* (planned reps / load) is never its *result*.
///   Unspecified loads, times and distances stay unspecified — the app must
///   never invent actuals.
/// * Warm-up, skipped and incomplete sets are excluded from working-set
///   metrics but remain visible in history.
/// * Volume is load x reps (lb-reps / kg-reps), never plain lb/kg.
library;

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Fresh unique id with a readable prefix, e.g. `set-<uuid>`.
String uid([String prefix = 'id']) => '$prefix-${_uuid.v4()}';

/// Local calendar date as `YYYY-MM-DD`. Never derived from a UTC timestamp.
String localDate([DateTime? when]) {
  final d = when ?? DateTime.now();
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Measurement unit for loads.
enum Unit { lb, kg }

/// What a set's load means:
/// * [weighted] — external load (barbell, dumbbell, machine, …)
/// * [bodyweight] — unweighted bodyweight work (pull-ups, push-ups, …)
/// * [unrecorded] — the load was never specified; must stay unspecified.
enum LoadType { weighted, bodyweight, unrecorded }

/// How a [TrainingSet.plannedWeight] / [TrainingSet.actualWeight] reads:
/// * [total] — the whole external load, e.g. "185 lb total"
/// * [perHand] — per side implement, e.g. "40 lb each" (dumbbells)
/// * [added] — load added to bodyweight, e.g. "25 lb added" (weighted pull-up)
enum WeightMode { total, perHand, added }

/// Lifecycle of a workout session.
enum WorkoutStatus { planned, active, completed, skipped }

/// One set inside an exercise: prescription on the left, evidence on the right.
///
/// `plannedReps` is a display string ("10" or "8-10"). `actualReps` holds what
/// was really performed, as a positive whole number string, or "" when the
/// set has no recorded result yet. `plannedWeight`/`actualWeight` are null
/// when unspecified — null must never be silently turned into a number.
class TrainingSet {
  TrainingSet({
    String? id,
    this.plannedReps = '8',
    this.plannedWeight,
    this.plannedRpe = '',
    this.plannedRir = '',
    this.actualReps = '',
    this.actualWeight,
    this.loadType = LoadType.unrecorded,
    this.weightMode = WeightMode.total,
    this.unit = Unit.lb,
    this.rpe = '',
    this.rir = '',
    this.completed = false,
    this.completedAsPlanned = false,
    this.warmup = false,
    this.skipped = false,
    this.notes = '',
    String? updatedAt,
  })  : id = id ?? uid('set'),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  final String id;
  final String plannedReps;
  final double? plannedWeight;
  final String plannedRpe;
  final String plannedRir;
  final String actualReps;
  final double? actualWeight;
  final LoadType loadType;
  final WeightMode weightMode;
  final Unit unit;
  final String rpe;
  final String rir;
  final bool completed;
  final bool completedAsPlanned;
  final bool warmup;
  final bool skipped;
  final String notes;
  final String updatedAt;

  TrainingSet copyWith({
    String? plannedReps,
    double? plannedWeight,
    bool clearPlannedWeight = false,
    String? plannedRpe,
    String? plannedRir,
    String? actualReps,
    double? actualWeight,
    bool clearActualWeight = false,
    LoadType? loadType,
    WeightMode? weightMode,
    Unit? unit,
    String? rpe,
    String? rir,
    bool? completed,
    bool? completedAsPlanned,
    bool? warmup,
    bool? skipped,
    String? notes,
    String? updatedAt,
  }) {
    return TrainingSet(
      id: id,
      plannedReps: plannedReps ?? this.plannedReps,
      plannedWeight: clearPlannedWeight ? null : (plannedWeight ?? this.plannedWeight),
      plannedRpe: plannedRpe ?? this.plannedRpe,
      plannedRir: plannedRir ?? this.plannedRir,
      actualReps: actualReps ?? this.actualReps,
      actualWeight: clearActualWeight ? null : (actualWeight ?? this.actualWeight),
      loadType: loadType ?? this.loadType,
      weightMode: weightMode ?? this.weightMode,
      unit: unit ?? this.unit,
      rpe: rpe ?? this.rpe,
      rir: rir ?? this.rir,
      completed: completed ?? this.completed,
      completedAsPlanned: completedAsPlanned ?? this.completedAsPlanned,
      warmup: warmup ?? this.warmup,
      skipped: skipped ?? this.skipped,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'plannedReps': plannedReps,
        'plannedWeight': plannedWeight,
        'plannedRpe': plannedRpe,
        'plannedRir': plannedRir,
        'actualReps': actualReps,
        'actualWeight': actualWeight,
        'loadType': loadType.name,
        'weightMode': weightMode.name,
        'unit': unit.name,
        'rpe': rpe,
        'rir': rir,
        'completed': completed,
        'completedAsPlanned': completedAsPlanned,
        'warmup': warmup,
        'skipped': skipped,
        'notes': notes,
        'updatedAt': updatedAt,
      };

  factory TrainingSet.fromJson(Map<String, dynamic> json) => TrainingSet(
        id: json['id'] as String? ?? uid('set'),
        plannedReps: json['plannedReps'] as String? ?? '8',
        plannedWeight: (json['plannedWeight'] as num?)?.toDouble(),
        plannedRpe: json['plannedRpe'] as String? ?? '',
        plannedRir: json['plannedRir'] as String? ?? '',
        actualReps: json['actualReps'] as String? ?? '',
        actualWeight: (json['actualWeight'] as num?)?.toDouble(),
        loadType: _loadTypeFrom(json['loadType'] as String?),
        weightMode: _weightModeFrom(json['weightMode'] as String?),
        unit: (json['unit'] as String?) == 'kg' ? Unit.kg : Unit.lb,
        rpe: json['rpe'] as String? ?? '',
        rir: json['rir'] as String? ?? '',
        completed: json['completed'] as bool? ?? false,
        completedAsPlanned: json['completedAsPlanned'] as bool? ?? false,
        warmup: json['warmup'] as bool? ?? false,
        skipped: json['skipped'] as bool? ?? false,
        notes: json['notes'] as String? ?? '',
        updatedAt: json['updatedAt'] as String?,
      );

  static LoadType _loadTypeFrom(String? raw) => LoadType.values.firstWhere(
        (v) => v.name == raw,
        orElse: () => LoadType.unrecorded,
      );

  static WeightMode _weightModeFrom(String? raw) => WeightMode.values.firstWhere(
        (v) => v.name == raw,
        orElse: () => WeightMode.total,
      );
}

/// One exercise (a block of sets) inside a workout.
class ExerciseBlock {
  ExerciseBlock({
    String? id,
    this.name = 'New exercise',
    this.restSec = 120,
    this.notes = '',
    List<TrainingSet>? sets,
    List<String>? deletedSetIds,
    String? updatedAt,
  })  : id = id ?? uid('exercise'),
        sets = sets ?? const [],
        deletedSetIds = deletedSetIds ?? const [],
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  final String id;
  final String name;
  final int restSec;
  final String notes;
  final List<TrainingSet> sets;
  final List<String> deletedSetIds;
  final String updatedAt;

  ExerciseBlock copyWith({
    String? name,
    int? restSec,
    String? notes,
    List<TrainingSet>? sets,
    List<String>? deletedSetIds,
  }) {
    return ExerciseBlock(
      id: id,
      name: name ?? this.name,
      restSec: restSec ?? this.restSec,
      notes: notes ?? this.notes,
      sets: sets ?? this.sets,
      deletedSetIds: deletedSetIds ?? this.deletedSetIds,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'restSec': restSec,
        'notes': notes,
        'sets': sets.map((s) => s.toJson()).toList(),
        'deletedSetIds': deletedSetIds,
        'updatedAt': updatedAt,
      };

  factory ExerciseBlock.fromJson(Map<String, dynamic> json) => ExerciseBlock(
        id: json['id'] as String? ?? uid('exercise'),
        name: json['name'] as String? ?? 'New exercise',
        restSec: (json['restSec'] as num?)?.toInt() ?? 120,
        notes: json['notes'] as String? ?? '',
        sets: ((json['sets'] as List?) ?? const [])
            .map((e) => TrainingSet.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        deletedSetIds: ((json['deletedSetIds'] as List?) ?? const []).map((e) => e as String).toList(),
        updatedAt: json['updatedAt'] as String?,
      );
}

/// One training session. `status` drives the lifecycle:
/// planned -> active -> completed (or discarded).
class WorkoutSession {
  WorkoutSession({
    String? id,
    this.name = 'Training session',
    String? date,
    this.timezone = 'UTC',
    String? createdAt,
    this.startedAt,
    this.completedAt,
    this.status = WorkoutStatus.active,
    List<ExerciseBlock>? exercises,
    this.notes = '',
    String? updatedAt,
  })  : id = id ?? uid('workout'),
        date = date ?? localDate(),
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        exercises = exercises ?? const [],
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  final String id;
  final String name;
  final String date;
  final String timezone;
  final String createdAt;
  final String? startedAt;
  final String? completedAt;
  final WorkoutStatus status;
  final List<ExerciseBlock> exercises;
  final String notes;
  final String updatedAt;

  WorkoutSession copyWith({
    String? name,
    String? date,
    String? startedAt,
    String? completedAt,
    bool clearCompletedAt = false,
    WorkoutStatus? status,
    List<ExerciseBlock>? exercises,
    String? notes,
  }) {
    return WorkoutSession(
      id: id,
      name: name ?? this.name,
      date: date ?? this.date,
      timezone: timezone,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      status: status ?? this.status,
      exercises: exercises ?? this.exercises,
      notes: notes ?? this.notes,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date,
        'timezone': timezone,
        'createdAt': createdAt,
        'startedAt': startedAt,
        'completedAt': completedAt,
        'status': status.name,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'notes': notes,
        'updatedAt': updatedAt,
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
        id: json['id'] as String? ?? uid('workout'),
        name: json['name'] as String? ?? 'Training session',
        date: json['date'] as String? ?? localDate(),
        timezone: json['timezone'] as String? ?? 'UTC',
        createdAt: json['createdAt'] as String?,
        startedAt: json['startedAt'] as String?,
        completedAt: json['completedAt'] as String?,
        status: WorkoutStatus.values.firstWhere(
          (v) => v.name == (json['status'] as String?),
          orElse: () => WorkoutStatus.completed,
        ),
        exercises: ((json['exercises'] as List?) ?? const [])
            .map((e) => ExerciseBlock.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        notes: json['notes'] as String? ?? '',
        updatedAt: json['updatedAt'] as String?,
      );
}

/// Factory for a blank, uncompleted set. Actuals always start empty —
/// a new row must never inherit anyone's results.
TrainingSet makeSet(Unit unit) => TrainingSet(unit: unit);

/// Factory for a new exercise with three blank working sets.
ExerciseBlock makeExercise(Unit unit, {int restSec = 120, String name = 'New exercise'}) =>
    ExerciseBlock(name: name, restSec: restSec, sets: [makeSet(unit), makeSet(unit), makeSet(unit)]);

/// Factory for a new blank active workout dated today.
WorkoutSession makeWorkout(Unit unit, {int restSec = 120, String name = 'Training session'}) {
  final now = DateTime.now().toIso8601String();
  final exercise = makeExercise(unit, restSec: restSec);
  return WorkoutSession(
    name: name,
    startedAt: now,
    status: WorkoutStatus.active,
    exercises: [exercise],
  );
}
