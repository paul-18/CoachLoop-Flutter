import 'dart:convert';
import 'dart:io';

import 'package:coach_loop_flutter/domain/completion.dart';
import 'package:coach_loop_flutter/domain/training_metrics.dart';
import 'package:coach_loop_flutter/domain/training_types.dart';
import 'package:flutter_test/flutter_test.dart';

final Map<String, dynamic> _rules = jsonDecode(
  File('test/fixtures/training_rules_v1.json').readAsStringSync(),
) as Map<String, dynamic>;

void main() {
  test('shared actual-reps vectors match the PWA fixture', () {
    for (final vector in _rules['actualReps'] as List<dynamic>) {
      final row = vector as Map<String, dynamic>;
      expect(parseExactReps(row['input'] as String), row['value'], reason: row['input'] as String);
    }
  });

  test('shared completion vectors match the PWA fixture', () {
    for (final vector in _rules['completion'] as List<dynamic>) {
      final row = vector as Map<String, dynamic>;
      final set = makeSet(Unit.lb).copyWith(
        plannedReps: row['plannedReps'] as String,
        actualReps: row['actualReps'] as String,
        plannedWeight: (row['plannedWeight'] as num?)?.toDouble(),
        actualWeight: (row['actualWeight'] as num?)?.toDouble(),
        loadType: LoadType.weighted,
      );
      if (row['completes'] != true) {
        expect(() => completedSetValues(set), throwsA(isA<SetCompletionException>()), reason: row['name'] as String);
        continue;
      }
      final result = completedSetValues(set);
      expect(result.actualReps, row['expectedActualReps'], reason: row['name'] as String);
      expect(result.actualWeight, row['expectedActualWeight'], reason: row['name'] as String);
      expect(result.completedAsPlanned, row['expectedAsPlanned'], reason: row['name'] as String);
    }
  });

  test('shared volume vectors match the PWA fixture', () {
    for (final vector in _rules['volume'] as List<dynamic>) {
      final row = vector as Map<String, dynamic>;
      final set = makeSet(Unit.lb).copyWith(
        completed: row['completed'] as bool,
        warmup: row['warmup'] as bool,
        skipped: row['skipped'] as bool,
        loadType: LoadType.values.byName(row['loadType'] as String),
        weightMode: row['weightMode'] == 'per_hand' ? WeightMode.perHand : WeightMode.total,
        actualReps: row['actualReps'] as String,
        actualWeight: (row['actualWeight'] as num?)?.toDouble(),
      );
      final workout = makeWorkout(Unit.lb).copyWith(
        exercises: [ExerciseBlock(sets: [set])],
      );
      final result = workoutLiftingVolume(workout, Unit.lb);
      expect(result.volume, row['expectedVolume'], reason: row['name'] as String);
      expect(result.countedSets, row['expectedCountedSets'], reason: row['name'] as String);
      expect(result.excludedSets, row['expectedExcludedSets'], reason: row['name'] as String);
    }
  });
}
