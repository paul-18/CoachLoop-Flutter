/// One exercise card: header, set rows, add-set button.
library;

import 'package:flutter/material.dart';

import '../../domain/training_types.dart';
import 'set_row.dart';

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.exerciseIndex,
    required this.onToggleCompleted,
    required this.onPatchSet,
    required this.onToggleSkipped,
    required this.onToggleWarmup,
    required this.onRemoveSet,
    required this.onAddSet,
    required this.onRename,
    required this.onEditRest,
    required this.onRemoveExercise,
  });

  final ExerciseBlock exercise;
  final int exerciseIndex;
  final void Function(String setId, TrainingSet draft) onToggleCompleted;
  final void Function(String setId, TrainingSet Function(TrainingSet) change) onPatchSet;
  final void Function(String setId) onToggleSkipped;
  final void Function(String setId) onToggleWarmup;
  final void Function(String setId) onRemoveSet;
  final VoidCallback onAddSet;
  final VoidCallback onRename;
  final VoidCallback onEditRest;
  final VoidCallback onRemoveExercise;

  @override
  Widget build(BuildContext context) {
    var number = 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                InkWell(
                  onTap: onEditRest,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      '${exercise.restSec}s rest',
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    switch (value) {
                      case 'rename':
                        onRename();
                      case 'remove':
                        onRemoveExercise();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename exercise')),
                    PopupMenuItem(value: 'remove', child: Text('Remove exercise')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...exercise.sets.map((set) {
              number++;
              final n = number;
              return SetRow(
                key: ValueKey(set.id),
                set: set,
                displayIndex: n,
                exerciseIndex: exerciseIndex,
                onToggleCompleted: (draft) => onToggleCompleted(set.id, draft),
                onPatch: (change) => onPatchSet(set.id, change),
                onToggleSkipped: () => onToggleSkipped(set.id),
                onToggleWarmup: () => onToggleWarmup(set.id),
                onRemove: () => onRemoveSet(set.id),
              );
            }),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: onAddSet,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add set'),
            ),
          ],
        ),
      ),
    );
  }
}
