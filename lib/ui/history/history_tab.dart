/// History tab: completed workouts, newest first. Tap for detail.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/training_types.dart';
import '../../state/providers.dart';

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  String _summary(WorkoutSession workout) {
    final sets = workout.exercises.expand((e) => e.sets).toList();
    final done = sets.where((s) => s.completed).length;
    final exercises = workout.exercises.length;
    return '$done/${sets.length} sets · $exercises exercise${exercises == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(workoutLogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: log.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load history: $e')),
        data: (data) {
          final done = data.completedWorkouts;
          if (done.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No completed workouts yet.\nFinish a workout and it will show up here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: done.length,
            itemBuilder: (context, index) {
              final workout = done[index];
              final date = DateTime.tryParse(workout.date);
              final dateLabel = date == null
                  ? workout.date
                  : DateFormat('EEE, MMM d, yyyy').format(date);
              return Card(
                child: ListTile(
                  title: Text(workout.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$dateLabel\n${_summary(workout)}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/history/${workout.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
