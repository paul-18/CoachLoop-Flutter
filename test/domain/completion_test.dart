/// Completion rule tests: the prescription/result split, evidence
/// validation, and the commit-visible-values behavior.
library;
import 'package:coach_loop_flutter/domain/completion.dart';
import 'package:coach_loop_flutter/domain/training_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseExactReps', () {
    test('accepts positive whole numbers only', () {
      expect(parseExactReps('8'), 8);
      expect(parseExactReps(' 10 '), 10);
      expect(parseExactReps(''), isNull);
      expect(parseExactReps('0'), isNull);
      expect(parseExactReps('8-10'), isNull);
      expect(parseExactReps('8.5'), isNull);
      expect(parseExactReps('each side'), isNull);
    });
  });

  group('setEvidenceError', () {
    test('valid evidence passes', () {
      final set = makeSet(Unit.lb).copyWith(actualReps: '8', rpe: '7');
      expect(setEvidenceError(set), isNull);
    });

    test('rejects non-numeric reps', () {
      final set = makeSet(Unit.lb).copyWith(actualReps: 'eight');
      expect(setEvidenceError(set), contains('positive whole number'));
    });

    test('rejects both RPE and RIR', () {
      final set = makeSet(Unit.lb).copyWith(actualReps: '8', rpe: '7', rir: '2');
      expect(setEvidenceError(set), contains('either RPE or RIR'));
    });

    test('rejects out-of-range RPE/RIR', () {
      expect(
        setEvidenceError(makeSet(Unit.lb).copyWith(actualReps: '8', rpe: '11')),
        contains('1 to 10'),
      );
      expect(
        setEvidenceError(makeSet(Unit.lb).copyWith(actualReps: '8', rir: '11')),
        contains('0 to 10'),
      );
    });
  });

  group('completedSetValues', () {
    test('commits the visible prescription when nothing was typed', () {
      final set = makeSet(Unit.lb).copyWith(
        plannedReps: '8',
        plannedWeight: 60,
        loadType: LoadType.weighted,
      );
      final values = completedSetValues(set);
      expect(values.actualReps, '8');
      expect(values.actualWeight, 60);
      expect(values.completedAsPlanned, isTrue);
    });

    test('honors typed values and marks not-as-planned', () {
      final set = makeSet(Unit.lb).copyWith(
        plannedReps: '8',
        plannedWeight: 60,
        loadType: LoadType.weighted,
        actualReps: '6',
        actualWeight: 55,
      );
      final values = completedSetValues(set);
      expect(values.actualReps, '6');
      expect(values.actualWeight, 55);
      expect(values.completedAsPlanned, isFalse);
    });

    test('never guesses reps for a range prescription', () {
      final set = makeSet(Unit.lb).copyWith(plannedReps: '8-10');
      expect(
        () => completedSetValues(set),
        throwsA(isA<SetCompletionException>().having(
          (e) => e.message,
          'message',
          contains('8-10'),
        )),
      );
    });

    test('rejects invalid typed reps', () {
      final set = makeSet(Unit.lb).copyWith(actualReps: 'lots');
      expect(() => completedSetValues(set), throwsA(isA<SetCompletionException>()));
    });

    test('keeps unspecified weight unspecified', () {
      final set = makeSet(Unit.lb).copyWith(plannedReps: '10');
      final values = completedSetValues(set);
      expect(values.actualWeight, isNull);
    });
  });

  group('hasWorkingStrength', () {
    test('ignores warm-up, skipped and incomplete sets', () {
      final done = makeSet(Unit.lb).copyWith(
        completed: true,
        actualReps: '8',
        actualWeight: 60,
        loadType: LoadType.weighted,
      );
      final warmup = done.copyWith(warmup: true);
      final skipped = done.copyWith(skipped: true, completed: false);
      final incomplete = makeSet(Unit.lb);
      final workout = makeWorkout(Unit.lb)
          .copyWith(exercises: [ExerciseBlock(sets: [warmup, skipped, incomplete])]);
      expect(hasWorkingStrength(workout), isFalse);

      final working = makeWorkout(Unit.lb)
          .copyWith(exercises: [ExerciseBlock(sets: [done])]);
      expect(hasWorkingStrength(working), isTrue);
    });
  });

  group('workoutCompletionSummary', () {
    test('summarizes done/total sets', () {
      final workout = makeWorkout(Unit.lb);
      expect(workoutCompletionSummary(workout), contains('Nothing is marked complete'));
      final done = workout.exercises.single.sets.first.copyWith(completed: true);
      final updated = workout.copyWith(
        exercises: [
          workout.exercises.single.copyWith(
            sets: [done, ...workout.exercises.single.sets.skip(1)],
          ),
        ],
      );
      expect(workoutCompletionSummary(updated), '1/3 sets complete.');
    });
  });
}
