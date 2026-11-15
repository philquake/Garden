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
import '../notify/notification_sync.dart';
import '../purchases/purchases.dart';
import '../state/garden_controller.dart';
import 'paywall.dart';
import 'toast.dart';

String _capitalise(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

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
          const SizedBox(height: 24),
          Text('Pick a flower', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [for (final id in flowerKinds) _flowerChoice(id)],
            ),
          ),
          const SizedBox(height: 24),
          Text('How do you track it?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
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
          const SizedBox(height: 24),
          Text('How often?', style: theme.textTheme.titleMedium),
          _scheduleTile(
            const Key('schedule-daily'),
            ScheduleKind.daily,
            'Every day',
          ),
          _scheduleTile(
            const Key('schedule-times'),
            ScheduleKind.timesPerWeek,
            'Times a week',
          ),
          if (_kind == ScheduleKind.timesPerWeek) _stepper(),
          _scheduleTile(
            const Key('schedule-weekday'),
            ScheduleKind.weekday,
            'One day a week',
          ),
          if (_kind == ScheduleKind.weekday) _weekdayChips(),
          const SizedBox(height: 16),
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
          const SizedBox(height: 24),
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
    final name = _capitalise(id);
    final scheme = Theme.of(context).colorScheme;
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
          width: 92,
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected ? scheme.primary.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FlowerView(look: pickerLook(id), size: 64),
              const SizedBox(height: 4),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scheduleTile(Key key, ScheduleKind kind, String title) {
    final selected = _kind == kind;
    return ListTile(
      key: key,
      selected: selected,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      title: Text(title),
      onTap: () => setState(() => _kind = kind),
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
