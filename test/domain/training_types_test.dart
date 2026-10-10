/// Domain rule tests: factories, ids, JSON round-trips, unspecified stays
/// unspecified.
library;
import 'package:coach_loop_flutter/domain/training_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('uid', () {
    test('generates unique prefixed ids', () {
      final a = uid('set');
      final b = uid('set');
      expect(a, startsWith('set-'));
      expect(a, isNot(equals(b)));
    });
  });

  group('localDate', () {
    test('formats a local calendar date', () {
      expect(localDate(DateTime(2026, 10, 5)), '2026-10-05');
    });
  });

  group('makeSet', () {
    test('starts blank and uncompleted with fresh ids', () {
      final a = makeSet(Unit.lb);
      final b = makeSet(Unit.lb);
      expect(a.id, isNot(equals(b.id)));
      expect(a.actualReps, '');
      expect(a.actualWeight, isNull);
      expect(a.plannedWeight, isNull);
      expect(a.completed, isFalse);
      expect(a.warmup, isFalse);
      expect(a.unit, Unit.lb);
    });
  });

  group('JSON round-trip', () {
    test('set survives encode/decode with unspecified values intact', () {
      final set = TrainingSet(
        plannedReps: '8-10',
        loadType: LoadType.weighted,
        weightMode: WeightMode.perHand,
        unit: Unit.kg,
        actualReps: '9',
        actualWeight: 22.5,
      );
      final restored = TrainingSet.fromJson(set.toJson());
      expect(restored.plannedReps, '8-10');
      expect(restored.loadType, LoadType.weighted);
      expect(restored.weightMode, WeightMode.perHand);
      expect(restored.unit, Unit.kg);
      expect(restored.actualReps, '9');
      expect(restored.actualWeight, 22.5);
    });

    test('null weights stay null (never invented)', () {
      final set = makeSet(Unit.lb);
      final restored = TrainingSet.fromJson(set.toJson());
      expect(restored.plannedWeight, isNull);
      expect(restored.actualWeight, isNull);
    });

    test('workout round-trips with exercises and sets', () {
      final workout = makeWorkout(Unit.kg, name: 'Pull day');
      final restored = WorkoutSession.fromJson(workout.toJson());
      expect(restored.name, 'Pull day');
      expect(restored.exercises.length, 1);
      expect(restored.exercises.single.sets.length, 3);
      expect(restored.status, WorkoutStatus.active);
    });

    test('unknown enum strings fall back safely', () {
      final set = TrainingSet.fromJson({
        'id': 'set-x',
        'loadType': 'bogus',
        'weightMode': 'bogus',
        'unit': 'bogus',
      });
      expect(set.loadType, LoadType.unrecorded);
      expect(set.weightMode, WeightMode.total);
      expect(set.unit, Unit.lb);
    });
  });
}
