/// Workout tab: empty state with guidance, or the active workout editor.
///
/// Empty states get guidance text — never fabricated history.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';
import 'workout_editor_screen.dart';

class WorkoutTab extends ConsumerStatefulWidget {
  const WorkoutTab({super.key});

  @override
  ConsumerState<WorkoutTab> createState() => _WorkoutTabState();
}

class _WorkoutTabState extends ConsumerState<WorkoutTab> {
  final _nameController = TextEditingController();
  var _starting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await ref.read(workoutControllerProvider.notifier).startWorkout(name: _nameController.text);
      _nameController.clear();
    } on StateError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = ref.watch(workoutLogProvider);
    return log.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Could not load workouts: $e'))),
      data: (data) {
        final active = data.activeWorkout;
        if (active != null) {
          // The editor brings its own Scaffold/AppBar (title, Finish, menu),
          // so the tab must not wrap it in another one.
          // Key by id so a fresh editor state mounts per workout.
          return WorkoutEditorScreen(key: ValueKey(active.id), workoutId: active.id);
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Workout'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
          body: _EmptyState(
            nameController: _nameController,
            starting: _starting,
            onStart: _start,
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.nameController,
    required this.starting,
    required this.onStart,
  });

  final TextEditingController nameController;
  final bool starting;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            const Icon(Icons.fitness_center, size: 56, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'No active workout',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Start a blank session, add your exercises, and log each set as '
              'you go. Plans stay plans until you record what you actually did — '
              'everything is saved on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Workout name',
                hintText: 'Training session',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onStart(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: starting ? null : onStart,
              icon: starting
                  ? const SizedBox.square(
                      dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              label: const Text('Start workout'),
            ),
          ],
        ),
      ),
    );
  }
}
