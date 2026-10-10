/// Active workout editor: exercises, set logging, rest timer, finish.
///
/// The screen keeps the device awake while mounted (parity with the PWA's
/// wake lock) and releases it on the way out.
library;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/completion.dart';
import '../../domain/training_types.dart';
import '../../domain/workout_transitions.dart';
import '../../services/wake_lock.dart';
import '../../state/providers.dart';
import 'exercise_card.dart';
import 'rest_timer.dart';

class WorkoutEditorScreen extends ConsumerStatefulWidget {
  const WorkoutEditorScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  ConsumerState<WorkoutEditorScreen> createState() => _WorkoutEditorScreenState();
}

class _WorkoutEditorScreenState extends ConsumerState<WorkoutEditorScreen> {
  int _restId = 0;
  Duration? _restTotal;
  String _restNextLabel = '';
  late final WakeLock _wakeLock;

  @override
  void initState() {
    super.initState();
    // Capture the wake lock now: ref is unsafe to touch in dispose().
    _wakeLock = ref.read(wakeLockProvider);
    _wakeLock.setEnabled(true);
  }

  @override
  void dispose() {
    _wakeLock.setEnabled(false);
    super.dispose();
  }

  WorkoutSession? _workout(WorkoutLog log) =>
      log.workouts.where((w) => w.id == widget.workoutId).firstOrNull;

  WorkoutSession _replaceSet(
    WorkoutSession workout,
    String exerciseId,
    String setId,
    TrainingSet Function(TrainingSet) change,
  ) {
    return workout.copyWith(
      exercises: workout.exercises.map((e) {
        if (e.id != exerciseId) return e;
        return e.copyWith(
          sets: e.sets.map((s) => s.id == setId ? change(s) : s).toList(),
        );
      }).toList(),
    );
  }

  Future<void> _save(WorkoutSession workout) =>
      ref.read(workoutControllerProvider.notifier).saveWorkout(workout);

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleCompleted(String exerciseId, String setId, TrainingSet draft) async {
    final workout = _workout(ref.read(workoutLogProvider).value ?? const WorkoutLog());
    if (workout == null) return;
    final set = workout.exercises
        .firstWhere((e) => e.id == exerciseId)
        .sets
        .firstWhere((s) => s.id == setId);
    if (set.completed) {
      await _save(_replaceSet(
        workout,
        exerciseId,
        setId,
        (s) => s.copyWith(completed: false, completedAsPlanned: false),
      ));
      return;
    }
    // Merge the row's typed draft first, then commit the visible values.
    final merged = _replaceSet(workout, exerciseId, setId, (_) => draft);
    try {
      final result = withCompletedSet(merged, exerciseId, setId);
      await _save(result.workout);
      if (result.restSec > 0) _startRest(result.restSec, _nextLabel(result.workout, exerciseId));
    } on SetCompletionException catch (e) {
      _showError(e.message);
    }
  }

  /// Name of the next exercise with unfinished work, for the rest alert.
  String _nextLabel(WorkoutSession workout, String currentExerciseId) {
    var seenCurrent = false;
    for (final e in workout.exercises) {
      if (e.id == currentExerciseId) {
        seenCurrent = true;
        continue;
      }
      if (seenCurrent && e.sets.any((s) => !s.completed && !s.skipped)) return e.name;
    }
    return '';
  }

  void _startRest(int seconds, String nextLabel) {
    setState(() {
      _restId++;
      _restTotal = Duration(seconds: seconds);
      _restNextLabel = nextLabel;
    });
  }

  Future<void> _onRestExpired() async {
    final label = _restNextLabel;
    setState(() => _restTotal = null);
    // Silent alert, and only when the app isn't in front of the user —
    // while visible, the on-screen timer already said it.
    final enabled = await ref.read(notificationsEnabledProvider.future);
    final visible = ref.read(appVisibilityProvider);
    if (enabled && !visible) {
      await ref.read(notificationServiceProvider).showRestComplete(label);
    }
  }

  Future<void> _addExercise() async {
    final nameController = TextEditingController();
    final restController = TextEditingController(text: '120');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add exercise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Exercise name'),
              textCapitalization: TextCapitalization.words,
            ),
            TextField(
              controller: restController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Rest (seconds)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    if (result != true || !mounted) return;
    final log = ref.read(workoutLogProvider).value;
    final workout = log == null ? null : _workout(log);
    if (workout == null) return;
    final name = nameController.text.trim();
    final rest = int.tryParse(restController.text.trim()) ?? 120;
    final exercise = makeExercise(Unit.lb,
        name: name.isEmpty ? 'New exercise' : name, restSec: rest.clamp(0, 3600));
    await _save(workout.copyWith(exercises: [...workout.exercises, exercise]));
  }

  Future<void> _renameExercise(ExerciseBlock exercise) async {
    final controller = TextEditingController(text: exercise.name);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename exercise'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (result != true || !mounted) return;
    final log = ref.read(workoutLogProvider).value;
    final workout = log == null ? null : _workout(log);
    if (workout == null) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;
    await _save(workout.copyWith(
      exercises: workout.exercises
          .map((e) => e.id == exercise.id ? e.copyWith(name: name) : e)
          .toList(),
    ));
  }

  Future<void> _editRest(ExerciseBlock exercise) async {
    final controller = TextEditingController(text: exercise.restSec.toString());
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rest between sets'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Seconds', suffixText: 's'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (result != true || !mounted) return;
    final log = ref.read(workoutLogProvider).value;
    final workout = log == null ? null : _workout(log);
    if (workout == null) return;
    final rest = (int.tryParse(controller.text.trim()) ?? exercise.restSec).clamp(0, 3600);
    await _save(workout.copyWith(
      exercises: workout.exercises
          .map((e) => e.id == exercise.id ? e.copyWith(restSec: rest) : e)
          .toList(),
    ));
  }

  Future<void> _renameWorkout(WorkoutSession workout) async {
    final controller = TextEditingController(text: workout.name);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename workout'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (result != true || !mounted) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;
    await _save(workout.copyWith(name: name));
  }

  Future<void> _finish(WorkoutSession workout) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish workout?'),
        content: Text(workoutCompletionSummary(workout)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: const Text('Keep training')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Finish')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(workoutControllerProvider.notifier).finishWorkout(workout.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout completed')));
      }
    } on StateError catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _discard(WorkoutSession workout) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard workout?'),
        content: const Text('The unfinished workout and its logged sets will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(workoutControllerProvider.notifier).discardWorkout(workout.id);
    } on StateError catch (e) {
      _showError(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = ref.watch(workoutLogProvider);
    return log.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Could not load workout: $e'))),
      data: (data) {
        final workout = _workout(data);
        if (workout == null) {
          return const Scaffold(body: Center(child: Text('Workout not found.')));
        }
        return Scaffold(
          appBar: AppBar(
            title: InkWell(
              onTap: () => _renameWorkout(workout),
              child: Text(workout.name),
            ),
            actions: [
              TextButton(
                onPressed: () => _finish(workout),
                child: const Text('Finish'),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'discard') _discard(workout);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'discard', child: Text('Discard workout')),
                ],
              ),
            ],
          ),
          body: SafeArea(
            // The rest timer sits above the scrollable exercise list (not
            // inside it): ListView builds lazily, so a timer scrolled out
            // of view would never tick and the rest alert would never fire.
            child: Column(
              children: [
                if (_restTotal != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: RestTimer(
                      // Key by rest id so a new rest always mounts a fresh
                      // countdown instead of reusing the old one's state.
                      key: ValueKey(_restId),
                      total: _restTotal!,
                      nextLabel: _restNextLabel,
                      onExpired: _onRestExpired,
                      onSkip: () => setState(() => _restTotal = null),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                ...workout.exercises.map((exercise) => ExerciseCard(
                      key: ValueKey(exercise.id),
                      exercise: exercise,
                      exerciseIndex: workout.exercises.indexOf(exercise),
                      onToggleCompleted: (setId, draft) =>
                          _toggleCompleted(exercise.id, setId, draft),
                      onPatchSet: (setId, change) async {
                        final current = _workout(
                            ref.read(workoutLogProvider).value ?? const WorkoutLog());
                        if (current == null) return;
                        await _save(_replaceSet(current, exercise.id, setId, change));
                      },
                      onToggleSkipped: (setId) async {
                        final current = _workout(
                            ref.read(workoutLogProvider).value ?? const WorkoutLog());
                        if (current == null) return;
                        await _save(_replaceSet(
                          current,
                          exercise.id,
                          setId,
                          (s) => s.skipped
                              ? s.copyWith(skipped: false)
                              : s.copyWith(
                                  skipped: true, completed: false, completedAsPlanned: false),
                        ));
                      },
                      onToggleWarmup: (setId) async {
                        final current = _workout(
                            ref.read(workoutLogProvider).value ?? const WorkoutLog());
                        if (current == null) return;
                        await _save(_replaceSet(current, exercise.id, setId,
                            (s) => s.copyWith(warmup: !s.warmup)));
                      },
                      onRemoveSet: (setId) async {
                        final current = _workout(
                            ref.read(workoutLogProvider).value ?? const WorkoutLog());
                        if (current == null) return;
                        await _save(current.copyWith(
                          exercises: current.exercises
                              .map((e) => e.id == exercise.id
                                  ? e.copyWith(
                                      sets: e.sets.where((s) => s.id != setId).toList(),
                                      deletedSetIds: [...e.deletedSetIds, setId],
                                    )
                                  : e)
                              .toList(),
                        ));
                      },
                      onAddSet: () async {
                        final current = _workout(
                            ref.read(workoutLogProvider).value ?? const WorkoutLog());
                        if (current == null) return;
                        await _save(current.copyWith(
                          exercises: current.exercises
                              .map((e) => e.id == exercise.id
                                  ? e.copyWith(sets: [...e.sets, makeSet(Unit.lb)])
                                  : e)
                              .toList(),
                        ));
                      },
                      onRename: () => _renameExercise(exercise),
                      onEditRest: () => _editRest(exercise),
                      onRemoveExercise: () async {
                        final current = _workout(
                            ref.read(workoutLogProvider).value ?? const WorkoutLog());
                        if (current == null) return;
                        await _save(current.copyWith(
                          exercises: current.exercises
                              .where((e) => e.id != exercise.id)
                              .toList(),
                        ));
                      },
                    )),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add),
                  label: const Text('Add exercise'),
                ),
                const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
