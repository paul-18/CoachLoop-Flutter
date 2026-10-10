/// Rest countdown, driven by timer ticks.
///
/// Each tick subtracts the tick interval from the remaining time, so the
/// countdown follows whatever clock drives the [Timer]s: real time in the
/// app, fake time in widget tests. (A deadline-based design was tried first,
/// but `DateTime.now()` stays real inside widget tests while `Timer`s follow
/// the fake clock, so expiry could never be tested.)
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

class RestTimer extends StatefulWidget {
  const RestTimer({
    super.key,
    required this.total,
    required this.nextLabel,
    required this.onExpired,
    required this.onSkip,
  });

  /// How long the rest lasts from when the timer mounts.
  final Duration total;
  final String nextLabel;
  final VoidCallback onExpired;
  final VoidCallback onSkip;

  @override
  State<RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends State<RestTimer> {
  static const _tick = Duration(milliseconds: 250);

  late Duration _remaining;
  Timer? _timer;
  var _fired = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.total;
    _timer = Timer.periodic(_tick, (_) {
      if (!mounted || _fired) return;
      _remaining -= _tick;
      if (_remaining <= Duration.zero) {
        _fired = true;
        _timer?.cancel();
        _timer = null;
        setState(() {});
        widget.onExpired();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _label {
    final total = _remaining.inSeconds.clamp(0, 359999);
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: limeAccent.withValues(alpha: 0.12),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, color: limeAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rest $_label',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    widget.nextLabel.isNotEmpty
                        ? 'Next: ${widget.nextLabel}'
                        : 'All work complete',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: widget.onSkip, child: const Text('Skip')),
          ],
        ),
      ),
    );
  }
}
