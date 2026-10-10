/// Training calculations: unit conversion and lifting volume.
///
/// Ported from the PWA's `app/domain/training-metrics.ts`. The truthfulness
/// rule: volume is load x reps, reported as "lb-reps" / "kg-reps" — never
/// plain lb/kg. Warm-up, skipped and incomplete sets are excluded, as is any
/// set without an explicit positive external load. Bodyweight work is real
/// training but is never invented as external lifting volume.
library;

import 'completion.dart';
import 'training_types.dart';

const double _lbToKg = 0.45359237;

/// Convert a load between units.
double convertWeight(double value, Unit from, Unit to) {
  if (from == to) return value;
  return from == Unit.lb ? value * _lbToKg : value / _lbToKg;
}

/// Honest unit label for a volume figure.
String volumeUnitLabel(Unit unit) => unit == Unit.lb ? 'lb·reps' : 'kg·reps';

/// External-load volume over a workout's working sets.
class LiftingVolume {
  LiftingVolume({required this.volume, required this.countedSets, required this.excludedSets});
  final double volume;
  final int countedSets;
  final int excludedSets;
}

/// Sum load x reps across completed, non-warmup, weighted sets with an
/// explicit positive load. `perHand` loads count both sides.
///
/// Warm-up, skipped and incomplete sets are excluded from the total but
/// still tallied in [LiftingVolume.excludedSets], so the UI can be honest
/// about what the number leaves out.
LiftingVolume workoutLiftingVolume(WorkoutSession workout, Unit unit) {
  var volume = 0.0;
  var counted = 0;
  var excluded = 0;
  for (final exercise in workout.exercises) {
    for (final set in exercise.sets) {
      if (!set.completed || set.warmup || set.skipped) {
        excluded++;
        continue;
      }
      final reps = parseExactReps(set.actualReps);
      final weight = set.actualWeight;
      if (set.loadType != LoadType.weighted ||
          weight == null ||
          !weight.isFinite ||
          weight <= 0 ||
          reps == null) {
        excluded++;
        continue;
      }
      volume += convertWeight(weight, set.unit, unit) * reps * (set.weightMode == WeightMode.perHand ? 2 : 1);
      counted++;
    }
  }
  return LiftingVolume(volume: volume, countedSets: counted, excludedSets: excluded);
}
