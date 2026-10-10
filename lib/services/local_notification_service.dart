/// Real [NotificationService] backed by flutter_local_notifications.
///
/// Silent by design (no sound/vibration) to match the app's quiet-controls
/// preference. Permission is only ever requested from the Settings toggle's
/// tap — a user gesture, as iOS requires.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/notifications.dart';

/// Stable id so a new rest alert replaces the previous one.
const int _restNotificationId = 7;

class LocalNotificationService implements NotificationService {
  FlutterLocalNotificationsPlugin? _plugin;
  var _supported = false;
  var _lastKnown = NotificationPermission.denied;

  @override
  Future<void> initialize({required void Function() onTap}) async {
    final plugin = FlutterLocalNotificationsPlugin();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
      ),
    );
    try {
      _supported = await plugin.initialize(
            settings: settings,
            onDidReceiveNotificationResponse: (_) => onTap(),
          ) ??
          false;
      _plugin = plugin;
      if (_supported) _lastKnown = await currentPermission();
    } catch (_) {
      _supported = false;
    }
  }

  @override
  Future<NotificationPermission> currentPermission() async {
    if (!_supported) return NotificationPermission.unsupported;
    final plugin = _plugin;
    // On web the browser is the source of truth; the OS wrappers below
    // cover Android/iOS permission state.
    final web = plugin?.resolvePlatformSpecificImplementation<
        WebFlutterLocalNotificationsPlugin>();
    if (web != null) {
      if (!WebFlutterLocalNotificationsPlugin.isSupported) {
        return NotificationPermission.unsupported;
      }
      return switch (web.permissionStatus) {
        WebNotificationPermission.granted => NotificationPermission.granted,
        WebNotificationPermission.denied => NotificationPermission.denied,
        WebNotificationPermission.defaultPermissions =>
          NotificationPermission.notDetermined,
      };
    }
    final android = plugin?.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false
          ? NotificationPermission.granted
          : NotificationPermission.notDetermined;
    }
    final ios = plugin?.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final options = await ios.checkPermissions();
      return options?.isEnabled ?? false
          ? NotificationPermission.granted
          : NotificationPermission.notDetermined;
    }
    return _lastKnown;
  }

  @override
  Future<NotificationPermission> requestPermission() async {
    final plugin = _plugin;
    if (!_supported || plugin == null) return NotificationPermission.unsupported;
    var sawImplementation = false;
    var granted = false;

    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      sawImplementation = true;
      granted = await android.requestNotificationsPermission() ?? false;
    }
    final ios = plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      sawImplementation = true;
      granted = await ios.requestPermissions(alert: true, sound: false, badge: false) ?? false;
    }
    final web = plugin.resolvePlatformSpecificImplementation<WebFlutterLocalNotificationsPlugin>();
    if (web != null) {
      sawImplementation = true;
      // Browsers only prompt from a real user gesture; our caller is the
      // Settings toggle's tap, which qualifies.
      granted = await web.requestNotificationsPermission() ?? false;
    }
    if (!sawImplementation) return NotificationPermission.unsupported;
    _lastKnown = granted ? NotificationPermission.granted : NotificationPermission.denied;
    return _lastKnown;
  }

  @override
  Future<void> showRestComplete(String nextLabel) async {
    final plugin = _plugin;
    if (!_supported || plugin == null || _lastKnown != NotificationPermission.granted) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'rest',
        'Rest timer',
        importance: Importance.high,
        priority: Priority.high,
        silent: true,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: false, presentBadge: false),
      macOS: DarwinNotificationDetails(presentAlert: true, presentSound: false, presentBadge: false),
      web: WebNotificationDetails(isSilent: true),
    );
    await plugin.show(
      id: _restNotificationId,
      title: 'Rest over',
      body: nextLabel.isNotEmpty ? 'Next: $nextLabel' : 'Time for your next set',
      notificationDetails: details,
    );
  }
}

/// Test double: permission is set directly, shown alerts are recorded.
class FakeNotificationService implements NotificationService {
  var permission = NotificationPermission.denied;
  final shownRestAlerts = <String>[];
  void Function()? onTap;

  @override
  Future<void> initialize({required void Function() onTap}) async {
    this.onTap = onTap;
  }

  @override
  Future<NotificationPermission> currentPermission() async => permission;

  @override
  Future<NotificationPermission> requestPermission() async => permission;

  @override
  Future<void> showRestComplete(String nextLabel) async {
    shownRestAlerts.add(nextLabel);
  }
}
