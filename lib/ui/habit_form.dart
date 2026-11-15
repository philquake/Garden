import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/day.dart';
import '../domain/habit_config.dart';
import '../domain/format.dart';
import '../domain/ids.dart';
import '../domain/schedule.dart';
import '../domain/stats.dart';
import '../flower/flower_view.dart';
import '../flower/look.dart';
import '../flower/plants.dart';
import '../notify/notification_sync.dart';
import '../purchases/purchases.dart';
import '../state/garden_controller.dart';
import 'paywall.dart';
import 'theme.dart';
import 'toast.dart';

class HabitForm extends ConsumerStatefulWidget {
  const HabitForm({super.key, this.existing});
  final HabitConfig? existing;

  @override
  ConsumerState<HabitForm> createState() => _HabitFormState();
}

class _HabitFormState extends ConsumerState<HabitForm> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _target = TextEditingController(text: '1');
  late final _unit = TextEditingController();
  late String _flowerId;
  late PlantGroup _group;
  late ScheduleKind _kind;
  bool _numeric = false;
  bool _atMost = false;
  int _times = 3;
  int _weekday = 1;
  bool _remind = false;
  int _minutes = 540;
  bool _nameError = false;
  bool _targetError = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _flowerId = e?.flowerId ?? flowerKinds.first;
    _group = plantOf(_flowerId)?.group ?? PlantGroup.flowering;
    _kind = e?.schedule.kind ?? ScheduleKind.daily;
    if (e != null) {
      if (_kind == ScheduleKind.timesPerWeek) _times = e.schedule.value;
      if (_kind == ScheduleKind.weekday) _weekday = e.schedule.value;
      _numeric = !e.isYesNo;
      _atMost = e.goal.atMost;
      _target.text = formatNum(e.goal.target);
      _unit.text = e.unit;
      final r = e.reminderMinutes;
      if (r != null) {
        _remind = true;
        _minutes = r;
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _unit.dispose();
    super.dispose();
  }

  Schedule get _schedule => switch (_kind) {
    ScheduleKind.daily => const Schedule.daily(),
    ScheduleKind.timesPerWeek => Schedule.timesPerWeek(_times),
    ScheduleKind.weekday => Schedule.weekday(_weekday),
  };

  /// Asked the first time a reminder is switched on, never at launch.
  Future<void> _askPermission() async {
    try {
      final granted = await ref
          .read(notificationSchedulerProvider)
          .requestPermission();
      if (!granted && mounted) {
        showToast(
          context,
          'Notifications are off for Garden. You can turn them on in your '
          "phone's settings.",
        );
      }
    } catch (_) {
      // The reminder is still saved; notifications simply may not show.
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _minutes ~/ 60, minute: _minutes % 60),
    );
    if (t != null && mounted) {
      setState(() => _minutes = t.hour * 60 + t.minute);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    final target = _numeric
        ? num.tryParse(_target.text.trim().replaceAll(',', '.'))
        : 1;
    final nameBad = name.isEmpty;
    final targetBad = target == null || target < 0 || (target == 0 && !_atMost);
    if (nameBad || targetBad) {
      setState(() {
        _nameError = nameBad;
        _targetError = targetBad;
      });
      return;
    }
    setState(() => _saving = true);
    final garden = ref.read(gardenProvider.notifier);
    final existing = widget.existing;
    final config = HabitConfig(
      id: existing?.id ?? newHabitId(),
      name: name,
      flowerId: _flowerId,
      schedule: _schedule,
      goal: Goal(target: target, atMost: _numeric && _atMost),
      unit: _numeric ? _unit.text.trim() : '',
      createdDay: existing?.createdDay ?? ref.read(todayProvider),
      reminderMinutes: _remind ? _minutes : null,
    );
    try {
      existing == null ? await garden.add(config) : await garden.update(config);
      if (mounted) Navigator.pop(context);
    } on FreeLimitReached {
      if (!mounted) return;
      setState(() => _saving = false);
      // Unlocking from here lets the person press Add habit again.
      await showPaywall(context, ref);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, retryText);
    }
  }

  Future<void> _remove() async {
    final h = widget.existing!;
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${h.name}?'),
        content: const Text(
          'This deletes the habit and its history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            key: const Key('confirm-remove'),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
          FilledButton(
            key: const Key('keep-it'),
            autofocus: true,
            style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    try {
      await ref.read(gardenProvider.notifier).remove(h.id);
      // The detail screen underneath would be empty; go home.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (_) {
      if (mounted) showToast(context, retryText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = widget.existing == null;
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'New habit' : 'Edit habit')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          TextField(
            key: const Key('name-field'),
            controller: _name,
            maxLength: 30,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'What will you do?',
              counterText: '',
              errorText: _nameError ? 'Give your habit a name.' : null,
            ),
            onChanged: (_) {
              if (_nameError) setState(() => _nameError = false);
            },
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Pick a plant',
            padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final g in PlantGroup.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: Key('plant-group-${g.name}'),
                            label: Text(g.label),
                            selected: g == _group,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _group = g),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 118,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final p in plants)
                        if (p.group == _group) _flowerChoice(p.id),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'How do you track it?',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  key: const Key('type'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Yes or no', key: Key('type-yesno')),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('A number', key: Key('type-number')),
                    ),
                  ],
                  selected: {_numeric},
                  onSelectionChanged: (s) => setState(() => _numeric = s.first),
                ),
                if (_numeric) ..._numberFields(),
              ],
            ),
          ),
          SectionCard(
            title: 'How often?',
            child: Column(
              children: [
                // Equal widths and heights, whichever label wraps.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _scheduleTile(
                        const Key('schedule-daily'),
                        ScheduleKind.daily,
                        'Every day',
                      ),
                      const SizedBox(width: 8),
                      _scheduleTile(
                        const Key('schedule-times'),
                        ScheduleKind.timesPerWeek,
                        'Times a week',
                      ),
                      const SizedBox(width: 8),
                      _scheduleTile(
                        const Key('schedule-weekday'),
                        ScheduleKind.weekday,
                        'One day a week',
                      ),
                    ],
                  ),
                ),
                if (_kind == ScheduleKind.timesPerWeek) ...[
                  const SizedBox(height: 8),
                  _stepper(),
                ],
                if (_kind == ScheduleKind.weekday) ...[
                  const SizedBox(height: 12),
                  _weekdayChips(),
                ],
              ],
            ),
          ),
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  key: const Key('reminder-switch'),
                  title: const Text('Remind me'),
                  value: _remind,
                  onChanged: (v) {
                    setState(() => _remind = v);
                    if (v) _askPermission();
                  },
                ),
                if (_remind)
                  ListTile(
                    key: const Key('reminder-time'),
                    title: const Text('At'),
                    trailing: Text(
                      MaterialLocalizations.of(context).formatTimeOfDay(
                        TimeOfDay(hour: _minutes ~/ 60, minute: _minutes % 60),
                      ),
                      style: theme.textTheme.titleMedium,
                    ),
                    onTap: _pickTime,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('save-button'),
            onPressed: _saving ? null : _save,
            child: Text(isNew ? 'Add habit' : 'Save'),
          ),
          if (!isNew) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                key: const Key('remove-button'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 48),
                  foregroundColor: theme.colorScheme.onSurface,
                ),
                onPressed: _saving ? null : _remove,
                child: const Text('Remove habit'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _numberFields() => [
    const SizedBox(height: 12),
    SegmentedButton<bool>(
      key: const Key('direction'),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: false, label: Text('At least')),
        ButtonSegment(value: true, label: Text('At most')),
      ],
      selected: {_atMost},
      onSelectionChanged: (s) => setState(() => _atMost = s.first),
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('target-field'),
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Each day',
              errorText: _targetError ? 'Enter a number.' : null,
            ),
            onChanged: (_) {
              if (_targetError) setState(() => _targetError = false);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            key: const Key('unit-field'),
            controller: _unit,
            maxLength: 12,
            decoration: const InputDecoration(
              labelText: 'Unit, like glasses',
              counterText: '',
            ),
          ),
        ),
      ],
    ),
  ];

  Widget _flowerChoice(String id) {
    final selected = id == _flowerId;
    final name = plantOf(id)?.name ?? id;
    final scheme = Theme.of(context).colorScheme;
    final accent = flowerColor(id, Theme.of(context).brightness);
    return Semantics(
      key: Key('flower-choice-$id'),
      button: true,
      selected: selected,
      label: 'Choose $name',
      excludeSemantics: true,
      onTap: () => setState(() => _flowerId = id),
      child: GestureDetector(
        onTap: () => setState(() => _flowerId = id),
        child: Container(
          width: 88,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.16)
                : scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent : scheme.outlineVariant,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FlowerView(look: pickerLook(id), size: 60),
              const SizedBox(height: 4),
              FittedBox(fit: BoxFit.scaleDown, child: Text(name, maxLines: 1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scheduleTile(Key key, ScheduleKind kind, String title) {
    final selected = _kind == kind;
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        selected: selected,
        child: Material(
          key: key,
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => _kind = kind),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepper() => Row(
    key: const Key('times-stepper'),
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Semantics(
        label: 'Fewer times a week',
        button: true,
        excludeSemantics: true,
        onTap: _times > 1 ? () => setState(() => _times--) : null,
        child: IconButton(
          key: const Key('times-minus'),
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: _times > 1 ? () => setState(() => _times--) : null,
        ),
      ),
      Text('$_times', style: Theme.of(context).textTheme.titleLarge),
      Semantics(
        label: 'More times a week',
        button: true,
        excludeSemantics: true,
        onTap: _times < 7 ? () => setState(() => _times++) : null,
        child: IconButton(
          key: const Key('times-plus'),
          icon: const Icon(Icons.add_circle_outline),
          onPressed: _times < 7 ? () => setState(() => _times++) : null,
        ),
      ),
    ],
  );

  Widget _weekdayChips() => Wrap(
    spacing: 8,
    children: [
      for (var d = 1; d <= 7; d++)
        Semantics(
          label: dayNames[d - 1],
          button: true,
          selected: _weekday == d,
          excludeSemantics: true,
          onTap: () => setState(() => _weekday = d),
          child: ChoiceChip(
            key: Key('weekday-$d'),
            label: Text(dayNames[d - 1].substring(0, 3)),
            selected: _weekday == d,
            onSelected: (_) => setState(() => _weekday = d),
          ),
        ),
    ],
  );
}
