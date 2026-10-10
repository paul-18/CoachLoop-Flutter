/// Set completion and evidence-validation rules.
///
/// Ported from the PWA's `app/domain/completion.ts`. The central promise:
/// checking a set commits the *visible* prescription as the result (the PWA
/// shows the plan as a placeholder, not an input value), but anything the
/// user typed must be a positive whole number of reps, and unspecified
/// values stay unspecified.
library;

import 'training_types.dart';

/// Thrown when a set cannot be completed because its typed evidence is
/// invalid. The message is user-facing.
class SetCompletionException implements Exception {
  SetCompletionException(this.message);
  final String message;
  @override
  String toString() => 'SetCompletionException: $message';
}

/// Parses a positive whole number ("8" -> 8). Returns null for anything
/// else — ranges, decimals, blanks, zero, negatives.
int? parseExactReps(String value) {
  final trimmed = value.trim();
  if (!RegExp(r'^[1-9]\d*$').hasMatch(trimmed)) return null;
  return int.parse(trimmed);
}

/// Validation for actual evidence (not editable prescription ranges).
/// Returns a user-facing error, or null when the evidence is fine.
String? setEvidenceError(TrainingSet set) {
  if (parseExactReps(set.actualReps) == null) {
    return 'Enter actual reps as a positive whole number';
  }
  if (set.rpe.trim().isNotEmpty && set.rir.trim().isNotEmpty) {
    return 'Use either RPE or RIR, not both';
  }
  bool effortOk(String text, double min, double max) {
    final t = text.trim();
    if (t.isEmpty) return true;
    final n = double.tryParse(t);
    return n != null && n >= min && n <= max;
  }

  if (!effortOk(set.rpe, 1, 10)) return 'Actual RPE must be a number from 1 to 10';
  if (!effortOk(set.rir, 0, 10)) return 'Actual RIR must be a number from 0 to 10';
  return null;
}

/// Result of committing a set's visible values.
class CompletedSetValues {
  CompletedSetValues({
    required this.actualReps,
    required this.actualWeight,
    required this.completedAsPlanned,
  });
  final String actualReps;
  final double? actualWeight;
  final bool completedAsPlanned;
}

/// Commit the set's visible prescription as its result, honoring anything the
/// user typed. Throws [SetCompletionException] with a user-facing message
/// when the evidence is invalid. Never invents reps: a range prescription
/// ("8-10") with no typed reps is an error, not a guess.
CompletedSetValues completedSetValues(TrainingSet set) {
  final enteredReps = set.actualReps.trim();
  if (enteredReps.isNotEmpty && parseExactReps(enteredReps) == null) {
    throw SetCompletionException('Enter the reps you performed as a positive whole number');
  }
  if (enteredReps.isEmpty && parseExactReps(set.plannedReps.trim()) == null) {
    if (RegExp(r'^\d+(?:\.\d+)?\s*-\s*\d+(?:\.\d+)?$').hasMatch(set.plannedReps.trim())) {
      throw SetCompletionException('Enter the reps you performed for the ${set.plannedReps} rep target.');
    }
    throw SetCompletionException('Enter the reps you performed for this target');
  }
  final actualReps = enteredReps.isNotEmpty ? set.actualReps : set.plannedReps;
  final error = setEvidenceError(set.copyWith(actualReps: actualReps));
  if (error != null) throw SetCompletionException(error);
  return CompletedSetValues(
    completedAsPlanned: enteredReps.isEmpty &&
        set.actualWeight == null &&
        set.rpe.trim().isEmpty &&
        set.rir.trim().isEmpty,
    actualReps: actualReps,
    // Commit the visible planned load when the user didn't type one.
    actualWeight: set.actualWeight ?? set.plannedWeight,
  );
}

/// True when the workout has at least one completed, non-skipped, non-warmup
/// set with real reps — the working-strength evidence rule.
bool hasWorkingStrength(WorkoutSession workout) => workout.exercises.any(
      (e) => e.sets.any((s) =>
          s.completed && !s.skipped && !s.warmup && parseExactReps(s.actualReps) != null),
    );

/// "3/5 sets complete." summary for the finish dialog.
String workoutCompletionSummary(WorkoutSession workout) {
  final sets = workout.exercises.expand((e) => e.sets).toList();
  final done = sets.where((s) => s.completed).length;
  if (done == 0) return 'Nothing is marked complete yet, but you can still save the session.';
  return '$done/${sets.length} sets complete.';
}
