/// One set row: prescription on the left, evidence entry on the right.
///
/// Draft text (typed reps/load) lives in this widget's controllers until the
/// set is checked done — only committed values ever reach the repository.
library;

import 'package:flutter/material.dart';

import '../../domain/training_types.dart';
import '../theme.dart';

class SetRow extends StatefulWidget {
  const SetRow({
    super.key,
    required this.set,
    required this.displayIndex,
    required this.exerciseIndex,
    required this.onToggleCompleted,
    required this.onPatch,
    required this.onToggleSkipped,
    required this.onToggleWarmup,
    required this.onRemove,
  });

  final TrainingSet set;
  final int displayIndex;

  /// Position of the parent exercise in the workout; with [displayIndex]
  /// this gives every set row a stable test key.
  final int exerciseIndex;
  final void Function(TrainingSet draft) onToggleCompleted;
  final void Function(TrainingSet Function(TrainingSet) change) onPatch;
  final VoidCallback onToggleSkipped;
  final VoidCallback onToggleWarmup;
  final VoidCallback onRemove;

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late final TextEditingController _reps;
  late final TextEditingController _weight;
  late final TextEditingController _rpe;

  @override
  void initState() {
    super.initState();
    _reps = TextEditingController(text: widget.set.actualReps);
    _weight = TextEditingController(
        text: widget.set.actualWeight?.toString() ?? '');
    _rpe = TextEditingController(text: widget.set.rpe);
  }

  @override
  void didUpdateWidget(SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resync only when the underlying set changed (e.g. completed
    // elsewhere), never clobber the user's in-progress typing.
    if (widget.set.actualReps != _reps.text &&
        widget.set.actualReps != oldWidget.set.actualReps) {
      _reps.text = widget.set.actualReps;
    }
    final weightText = widget.set.actualWeight?.toString() ?? '';
    if (weightText != _weight.text &&
        weightText != (oldWidget.set.actualWeight?.toString() ?? '')) {
      _weight.text = weightText;
    }
    if (widget.set.rpe != _rpe.text && widget.set.rpe != oldWidget.set.rpe) {
      _rpe.text = widget.set.rpe;
    }
  }

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    _rpe.dispose();
    super.dispose();
  }

  /// The set with the user's current typing merged in (not yet committed).
  TrainingSet get _draft => widget.set.copyWith(
        actualReps: _reps.text,
        actualWeight: double.tryParse(_weight.text.trim()),
        clearActualWeight: double.tryParse(_weight.text.trim()) == null,
        rpe: _rpe.text,
      );

  String get _plannedLabel {
    final reps = widget.set.plannedReps;
    final weight = widget.set.plannedWeight;
    if (widget.set.loadType == LoadType.bodyweight) return '$reps × BW';
    if (weight == null) return '$reps reps';
    final mode = switch (widget.set.weightMode) {
      WeightMode.total => '',
      WeightMode.perHand => ' each',
      WeightMode.added => ' added',
    };
    final w = weight % 1 == 0 ? weight.toInt().toString() : weight.toString();
    return '$reps × $w ${widget.set.unit.name}$mode';
  }

  @override
  Widget build(BuildContext context) {
    final set = widget.set;
    final dimmed = set.skipped;
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      set.warmup ? 'W' : '${widget.displayIndex}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: set.warmup ? limeAccent : Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _plannedLabel,
                      style: TextStyle(
                        decoration: dimmed ? TextDecoration.lineThrough : null,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  Checkbox(
                    key: Key('set-done-${widget.exerciseIndex}-${widget.displayIndex}'),
                    value: set.completed,
                    onChanged: dimmed ? null : (_) => widget.onToggleCompleted(_draft),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const SizedBox(width: 34),
                  Expanded(
                    child: TextField(
                      controller: _reps,
                      enabled: !dimmed && !set.completed,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Reps',
                        hintText: 'reps',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _weight,
                      enabled: !dimmed &&
                          !set.completed &&
                          set.loadType == LoadType.weighted,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Load (${set.unit.name})',
                        hintText: set.loadType == LoadType.bodyweight ? 'BW' : 'load',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<LoadType>(
                    value: set.loadType,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                          value: LoadType.weighted, child: Text('W')),
                      DropdownMenuItem(
                          value: LoadType.bodyweight, child: Text('BW')),
                      DropdownMenuItem(
                          value: LoadType.unrecorded, child: Text('–')),
                    ],
                    onChanged: dimmed || set.completed
                        ? null
                        : (v) {
                            if (v == null) return;
                            widget.onPatch(
                              (s) => _draft.copyWith(
                                loadType: v,
                                clearActualWeight: v != LoadType.weighted,
                              ),
                            );
                          },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const SizedBox(width: 34),
                  Expanded(
                    child: TextField(
                      controller: _rpe,
                      enabled: !dimmed && !set.completed,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'RPE (optional)',
                        hintText: '1–10',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) {
                      switch (value) {
                        case 'skip':
                          widget.onToggleSkipped();
                        case 'warmup':
                          widget.onToggleWarmup();
                        case 'remove':
                          widget.onRemove();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'skip',
                        child: Text(set.skipped ? 'Restore set' : 'Skip set'),
                      ),
                      PopupMenuItem(
                        value: 'warmup',
                        child: Text(set.warmup
                            ? 'Mark as working set'
                            : 'Mark as warm-up'),
                      ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove set'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
