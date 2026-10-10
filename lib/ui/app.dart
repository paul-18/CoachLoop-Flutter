/// App entry: router + theme. Tapping a rest notification returns here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import 'history/history_tab.dart';
import 'history/workout_detail_screen.dart';
import 'settings/settings_screen.dart';
import 'shell.dart';
import 'theme.dart';
import 'workout/workout_tab.dart';

class CoachLoopApp extends ConsumerStatefulWidget {
  const CoachLoopApp({super.key});

  @override
  ConsumerState<CoachLoopApp> createState() => _CoachLoopAppState();
}

class _CoachLoopAppState extends ConsumerState<CoachLoopApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/workout',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/workout', builder: (context, state) => const WorkoutTab()),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/history', builder: (context, state) => const HistoryTab()),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/history/:id',
          builder: (context, state) =>
              WorkoutDetailScreen(workoutId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      ],
    );
    // A tapped rest notification brings the user back to the workout.
    ref.read(notificationServiceProvider).initialize(onTap: () => _router.go('/workout'));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Coach Loop',
      theme: coachLoopTheme(),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
