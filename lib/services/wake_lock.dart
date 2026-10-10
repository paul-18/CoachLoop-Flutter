/// Wake-lock abstraction. The real implementation keeps the screen awake
/// during an active workout (parity with the PWA); the no-op keeps widget
/// tests hermetic.
library;

import 'package:wakelock_plus/wakelock_plus.dart';

abstract class WakeLock {
  Future<void> setEnabled(bool enabled);
}

class WakelockPlusWakeLock implements WakeLock {
  const WakelockPlusWakeLock();
  @override
  Future<void> setEnabled(bool enabled) =>
      enabled ? WakelockPlus.enable() : WakelockPlus.disable();
}

class NoopWakeLock implements WakeLock {
  const NoopWakeLock();
  @override
  Future<void> setEnabled(bool enabled) async {}
}
