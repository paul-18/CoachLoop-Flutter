import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/workout_repository.dart';
import '../services/local_notification_service.dart';
import '../services/wake_lock.dart';
import '../state/providers.dart';
import 'ui/app.dart';

/// Production entry point. Everything stays on the device: the database is
/// local SQLite, there are no accounts, no sync, no backend.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(DriftWorkoutRepository(db)),
        notificationServiceProvider.overrideWithValue(LocalNotificationService()),
        wakeLockProvider.overrideWithValue(const WakelockPlusWakeLock()),
      ],
      child: const CoachLoopApp(),
    ),
  );
}
