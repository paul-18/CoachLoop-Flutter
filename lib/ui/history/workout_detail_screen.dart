/// Completed workout detail: exercises with their recorded actuals.
///
/// Warm-up sets are marked W, skipped sets are dimmed and struck through —
/// both stay visible, matching the PWA.
library;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/training_types.dart';
import '../../state/providers.dart';
import '../theme.dart';

class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});

  final String workoutId;

  String _setLabel(TrainingSet set) {
    final reps = set.actualReps.isNotEmpty ? set.actualReps : '–';
    final weight = set.actualWeight;
    String load;
    if (set.loadType == LoadType.bodyweight) {
      load = 'BW';
    } else if (weight == null) {
      load = 'no load';
    } else {
      final w = weight % 1 == 0 ? weight.toInt().toString() : weight.toString();
      final mode = switch (set.weightMode) {
        WeightMode.total => '',
        WeightMode.perHand => ' each',
        WeightMode.added => ' added',
      };
      load = '$w ${set.unit.name}$mode';
    }
    final rpe = set.rpe.trim().isNotEmpty ? ' @${set.rpe.trim()}' : '';
    return '$reps × $load$rpe';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(workoutLogProvider);
    return log.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Could not load workout: $e'))),
      data: (data) {
        final workout = data.workouts.where((w) => w.id == workoutId).firstOrNull;
        if (workout == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Workout not found.')),
          );
        }
        final date = DateTime.tryParse(workout.date);
        final dateLabel = date == null ? workout.date : DateFormat('EEE, MMM d, yyyy').format(date);
        return Scaffold(
          appBar: AppBar(title: Text(workout.name)),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(dateLabel, style: const TextStyle(color: Colors.white60)),
              ),
              ...workout.exercises.map((exercise) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(exercise.name,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...exercise.sets.asMap().entries.map((entry) {
                            final i = entry.key;
                            final set = entry.value;
                            final prefix = set.warmup ? 'W' : '${i + 1}';
                            return Opacity(
                              opacity: set.skipped ? 0.45 : 1,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 30,
                                      child: Text(
                                        prefix,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: set.warmup ? limeAccent : Colors.white70,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _setLabel(set),
                                        style: TextStyle(
                                          decoration: set.skipped
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: set.completed
                                              ? Colors.white
                                              : Colors.white54,
                                        ),
                                      ),
                                    ),
                                    if (set.skipped)
                                      const Text('skipped',
                                          style: TextStyle(
                                              color: Colors.white38, fontSize: 12)),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }
}
