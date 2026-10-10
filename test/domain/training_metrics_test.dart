/// Volume truthfulness tests: load x reps, working sets only, honest units.
library;
import 'package:coach_loop_flutter/domain/training_metrics.dart';
import 'package:coach_loop_flutter/domain/training_types.dart';
import 'package:flutter_test/flutter_test.dart';

TrainingSet _workingSet({
  String actualReps = '8',
  double? actualWeight = 60,
  LoadType loadType = LoadType.weighted,
  WeightMode weightMode = WeightMode.total,
  Unit unit = Unit.lb,
  bool warmup = false,
}) =>
    makeSet(unit).copyWith(
      completed: true,
      actualReps: actualReps,
      actualWeight: actualWeight,
      loadType: loadType,
      weightMode: weightMode,
      warmup: warmup,
    );

WorkoutSession _workoutWith(List<TrainingSet> sets) =>
    makeWorkout(Unit.lb).copyWith(exercises: [ExerciseBlock(sets: sets)]);

void main() {
  group('workoutLiftingVolume', () {
    test('sums load x reps for working sets', () {
      final volume = workoutLiftingVolume(
        _workoutWith([_workingSet(), _workingSet(actualReps: '10', actualWeight: 60)]),
        Unit.lb,
      );
      expect(volume.volume, 60 * 8 + 60 * 10);
      expect(volume.countedSets, 2);
    });

    test('excludes warm-up, incomplete and skipped sets', () {
      final volume = workoutLiftingVolume(
        _workoutWith([
          _workingSet(warmup: true),
          _workingSet().copyWith(completed: false),
          _workingSet().copyWith(skipped: true, completed: false),
          _workingSet(),
        ]),
        Unit.lb,
      );
      expect(volume.volume, 60 * 8);
      expect(volume.countedSets, 1);
      expect(volume.excludedSets, 3);
    });

    test('excludes bodyweight, unrecorded and unspecified loads', () {
      final volume = workoutLiftingVolume(
        _workoutWith([
          _workingSet(loadType: LoadType.bodyweight),
          _workingSet(loadType: LoadType.unrecorded),
          _workingSet(actualWeight: null),
          _workingSet(actualWeight: 0),
          _workingSet(),
        ]),
        Unit.lb,
      );
      expect(volume.volume, 60 * 8);
      expect(volume.countedSets, 1);
    });

    test('never infers reps from ranges', () {
      final volume = workoutLiftingVolume(
        _workoutWith([_workingSet(actualReps: '8-10')]),
        Unit.lb,
      );
      expect(volume.volume, 0);
      expect(volume.countedSets, 0);
    });

    test('per-hand loads count both sides', () {
      final volume = workoutLiftingVolume(
        _workoutWith([_workingSet(weightMode: WeightMode.perHand, actualWeight: 40)]),
        Unit.lb,
      );
      expect(volume.volume, 40 * 8 * 2);
    });

    test('converts units honestly', () {
      final volume = workoutLiftingVolume(
        _workoutWith([_workingSet(unit: Unit.kg, actualWeight: 100)]),
        Unit.lb,
      );
      expect(volume.volume, closeTo(100 * 2.20462 * 8, 0.01));
    });
  });

  group('volumeUnitLabel', () {
    test('labels volume as load-reps, never plain load', () {
      expect(volumeUnitLabel(Unit.lb), 'lb·reps');
      expect(volumeUnitLabel(Unit.kg), 'kg·reps');
    });
  });

  group('convertWeight', () {
    test('converts both directions', () {
      expect(convertWeight(100, Unit.lb, Unit.kg), closeTo(45.359, 0.001));
      expect(convertWeight(45.359237, Unit.kg, Unit.lb), closeTo(100, 0.001));
      expect(convertWeight(60, Unit.lb, Unit.lb), 60);
    });
  });
}
