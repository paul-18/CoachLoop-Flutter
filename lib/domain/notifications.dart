/// Local notification contract for the workout flow.
///
/// Mirrors the PWA's `app/pwa/use-local-notifications.ts`: silent,
/// on-device alerts with no server involved. The app shows a "Rest over"
/// notification only when it isn't in the foreground; tapping it returns to
/// the app. Silent by design — no sound or vibration — matching the app's
/// quiet-controls preference.
///
/// UI code depends on this interface, never on the plugin directly, so tests
/// can substitute a fake.
library;

/// Result of asking the OS for notification permission.
enum NotificationPermission {
  /// The user granted permission: alerts may be shown.
  granted,

  /// The user denied (or revoked) permission: do not prompt again in-app.
  denied,

  /// The user hasn't decided yet: safe to prompt from a user gesture.
  notDetermined,

  /// Notifications aren't available on this device/browser at all.
  unsupported,
}

abstract class NotificationService {
  /// Prepare the plugin. [onTap] runs when the user taps a notification.
  Future<void> initialize({required void Function() onTap});

  /// Current permission without prompting.
  Future<NotificationPermission> currentPermission();

  /// Ask the user for permission. Must be called from a user gesture.
  Future<NotificationPermission> requestPermission();

  /// Show the silent rest-complete alert. Callers decide *when* (only when
  /// the app isn't in the foreground).
  Future<void> showRestComplete(String nextLabel);
}
