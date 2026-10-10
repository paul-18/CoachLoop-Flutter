/// Minimal settings: the rest-notification opt-in.
///
/// Mirrors the PWA's Settings → Notifications panel: the permission request
/// runs from the Enable button's tap (the user gesture iOS requires), and
/// the status text is honest about unsupported / denied / off / on.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/notifications.dart';
import '../../state/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  NotificationPermission? _permission;
  var _checking = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final p = await ref.read(notificationServiceProvider).currentPermission();
    if (mounted) {
      setState(() {
        _permission = p;
        _checking = false;
      });
    }
  }

  Future<void> _enable() async {
    final result = await ref.read(notificationServiceProvider).requestPermission();
    if (!mounted) return;
    setState(() => _permission = result);
    if (result == NotificationPermission.granted) {
      await ref.read(workoutControllerProvider.notifier).setNotificationsEnabled(true);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Rest notifications on')));
      }
    } else if (result == NotificationPermission.denied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Notifications are blocked — allow them in the system settings, then try again')));
    }
  }

  Future<void> _disable() async {
    await ref.read(workoutControllerProvider.notifier).setNotificationsEnabled(false);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Rest notifications off')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(notificationsEnabledProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notifications',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Silent rest-timer alerts. Everything stays on this device — '
                    'no server, no account.',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  if (_checking)
                    const CircularProgressIndicator()
                  else
                    _StatusAndAction(
                      permission: _permission!,
                      enabled: enabled.value ?? false,
                      onEnable: _enable,
                      onDisable: _disable,
                      onRecheck: _refresh,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Coach Loop Flutter · phase 1 experiment\n'
            'Local-only: your training data never leaves this device.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatusAndAction extends StatelessWidget {
  const _StatusAndAction({
    required this.permission,
    required this.enabled,
    required this.onEnable,
    required this.onDisable,
    required this.onRecheck,
  });

  final NotificationPermission permission;
  final bool enabled;
  final VoidCallback onEnable;
  final VoidCallback onDisable;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    final String status;
    switch (permission) {
      case NotificationPermission.unsupported:
        status = 'Not available on this device.';
      case NotificationPermission.denied:
        status = 'Blocked. Allow notifications in the system settings, then check again.';
      case NotificationPermission.notDetermined:
        status = 'Turn on to get a silent alert when a rest timer finishes.';
      case NotificationPermission.granted:
        status = enabled
            ? 'On. You\u2019ll get a silent alert when a rest timer finishes while the app isn\u2019t in front of you.'
            : 'Off. Turn on to get a silent alert when a rest timer finishes.';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(status, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 12),
        if (permission == NotificationPermission.unsupported)
          const SizedBox.shrink()
        else if (permission == NotificationPermission.denied)
          OutlinedButton(onPressed: onRecheck, child: const Text('Check again'))
        else if (enabled)
          OutlinedButton(onPressed: onDisable, child: const Text('Turn off'))
        else
          FilledButton(onPressed: onEnable, child: const Text('Enable notifications')),
      ],
    );
  }
}
