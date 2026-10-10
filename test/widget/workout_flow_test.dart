/// Widget tests: the core gym flow and the rest-timer notification rule.
///
/// Everything runs against [InMemoryWorkoutRepository] and
/// [FakeNotificationService] — no disk, no OS notifications.
library;
import 'package:coach_loop_flutter/data/workout_repository.dart';
import 'package:coach_loop_flutter/domain/notifications.dart';
import 'package:coach_loop_flutter/services/local_notification_service.dart';
import 'package:coach_loop_flutter/services/wake_lock.dart';
import 'package:coach_loop_flutter/state/providers.dart';
import 'package:coach_loop_flutter/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds the app with test doubles. Returns the container so tests can
/// drive providers (visibility, settings) that the app itself watches.
({Widget widget, ProviderContainer container}) _harness({
  required InMemoryWorkoutRepository repo,
  required FakeNotificationService notifications,
}) {
  final container = ProviderContainer(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      notificationServiceProvider.overrideWithValue(notifications),
      wakeLockProvider.overrideWithValue(const NoopWakeLock()),
    ],
  );
  final widget = UncontrolledProviderScope(
    container: container,
    child: const CoachLoopApp(),
  );
  return (widget: widget, container: container);
}

/// Adds an exercise through the dialog, targeting the dialog's own fields
/// (the overlay builds after the editor, so bare at(0)/at(1) would hit the
/// set rows behind it).
Future<void> _addExercise(WidgetTester tester, String name, String restSec) async {
  // The editor list builds lazily; scroll the button into view first.
  await tester.scrollUntilVisible(
    find.text('Add exercise'),
    600,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Add exercise'));
  await tester.pumpAndSettle();
  final fields = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), name);
  await tester.enterText(fields.at(1), restSec);
  await tester.tap(find.widgetWithText(FilledButton, 'Add'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('start workout → complete a set → finish → appears in History',
      (tester) async {
    final repo = InMemoryWorkoutRepository();
    final notifications = FakeNotificationService();
    final harness =
        _harness(repo: repo, notifications: notifications);
    addTearDown(repo.dispose);
    addTearDown(harness.container.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    // Empty state → start a named workout.
    expect(find.text('No active workout'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Leg day');
    await tester.tap(find.widgetWithText(FilledButton, 'Start workout'));
    await tester.pumpAndSettle();
    expect(find.text('Leg day'), findsWidgets);

    // Check the first set done with no typing: commits the visible plan.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.textContaining('Rest'), findsOneWidget);

    // Skip the rest timer so the test doesn't wait two minutes.
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(find.textContaining('Rest'), findsNothing);

    // Finish via the app bar, confirming in the dialog.
    await tester.tap(find.widgetWithText(TextButton, 'Finish'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await tester.pumpAndSettle();
    expect(find.text('No active workout'), findsOneWidget);

    // History shows the finished session.
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Leg day'), findsOneWidget);
    expect(find.textContaining('1/3 sets'), findsOneWidget);
  });

  testWidgets('rest expiry notifies only when the app is hidden', (tester) async {
    final repo = InMemoryWorkoutRepository();
    final notifications = FakeNotificationService()
      ..permission = NotificationPermission.granted;
    final harness =
        _harness(repo: repo, notifications: notifications);
    addTearDown(repo.dispose);
    addTearDown(harness.container.dispose);
    final container = harness.container;

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    // Start a workout and opt into notifications.
    await tester.tap(find.widgetWithText(FilledButton, 'Start workout'));
    await tester.pumpAndSettle();
    await repo.saveSetting('notificationsEnabled', 'true');
    container.invalidate(settingsProvider);
    // The app is backgrounded (e.g. user switched to a music app).
    container.read(appVisibilityProvider.notifier).setVisible(false);

    // Add Squat (2s rest) then Bench: completing a Squat set names Bench —
    // the next unfinished exercise — in the rest alert.
    await _addExercise(tester, 'Squat', '2');
    await _addExercise(tester, 'Bench', '120');

    // Squat's first set is the 4th checkbox (the default exercise has 3).
    // Squat is the second exercise: stable key, scrolled into view
    // (the list is lazy and the earlier scroll moved it offscreen).
    final squatFirstSet = find.byKey(const Key('set-done-1-1'));
    // scrollUntilVisible only moves one way; drag up to reveal the row above.
    await tester.dragUntilVisible(
      squatFirstSet,
      find.byType(Scrollable).first,
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();
    await tester.tap(squatFirstSet);
    await tester.pump();
    // DateTime.now() is real time in widget tests (pump() only fakes the
    // async clock), so expire the timer with real time.
    // The tick-driven timer follows the fake clock: 3s expires the 2s rest.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(notifications.shownRestAlerts, ['Bench']);
  });

  testWidgets('no notification while the app is visible', (tester) async {
    final repo = InMemoryWorkoutRepository();
    final notifications = FakeNotificationService()
      ..permission = NotificationPermission.granted;
    final harness =
        _harness(repo: repo, notifications: notifications);
    addTearDown(repo.dispose);
    addTearDown(harness.container.dispose);
    final container = harness.container;

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Start workout'));
    await tester.pumpAndSettle();
    await repo.saveSetting('notificationsEnabled', 'true');
    container.invalidate(settingsProvider);
    // App stays in the foreground: the on-screen timer is enough.
    container.read(appVisibilityProvider.notifier).setVisible(true);

    await _addExercise(tester, 'Squat', '2');
    await _addExercise(tester, 'Bench', '120');

    // Squat's first set is the 4th checkbox (the default exercise has 3).
    // The timer expires, but the app is visible so no alert goes out.
    // Squat is the second exercise: stable key, scrolled into view
    // (the list is lazy and the earlier scroll moved it offscreen).
    final squatFirstSet = find.byKey(const Key('set-done-1-1'));
    // scrollUntilVisible only moves one way; drag up to reveal the row above.
    await tester.dragUntilVisible(
      squatFirstSet,
      find.byType(Scrollable).first,
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();
    await tester.tap(squatFirstSet);
    await tester.pump();
    // The tick-driven timer follows the fake clock: 3s expires the 2s rest.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(notifications.shownRestAlerts, isEmpty);
  });
}
