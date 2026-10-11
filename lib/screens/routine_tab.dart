import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../services/ai_service.dart';
import '../services/launcher.dart';
import '../services/routine_ai.dart';
import '../services/routine_planner.dart';
import '../services/trip_service.dart';
import '../state/settings_store.dart';
import '../state/student_store.dart';
import '../utils/format.dart';
import 'location_picker_screen.dart';
import 'student_detail_screen.dart';

/// Weekly routine: the probable schedule, the least-travel visiting order
/// for each day, and an optional AI-written plan with tips.
class RoutineTab extends StatefulWidget {
  const RoutineTab({super.key});

  @override
  State<RoutineTab> createState() => _RoutineTabState();
}

class _RoutineTabState extends State<RoutineTab> {
  final _planner = RoutinePlanner();
  Future<List<DayPlan>>? _week;
  String _weekKey = '';
  int? _selectedDay;

  String? _aiText;
  bool _aiBusy = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final saved = p.getString('lastAiPlan');
      if (saved != null && mounted) setState(() => _aiText = saved);
    });
  }

  /// Recomputes only when the routine itself (days, times, places) or the
  /// planning settings change — not on every "+" press — so live-traffic
  /// lookups are not repeated needlessly.
  Future<List<DayPlan>> _weekFor(StudentStore store, SettingsStore settings) {
    final slots = RoutinePlanner.weeklyRoutine(store.current)
        .map((r) =>
            '${r.student.id}:${r.slot.weekday}:${r.slot.startMinutes}:${r.slot.durationMinutes}'
            ':${r.student.latitude}:${r.student.longitude}:${r.student.name}:${r.student.address}')
        .join(',');
    final key = '$slots|${settings.homeLat}|${settings.homeLng}|${settings.flexMinutes}';
    if (key != _weekKey || _week == null) {
      _weekKey = key;
      _week = _planner.planWeek(
        store.current,
        home: settings.hasHome ? LatLngPoint(settings.homeLat!, settings.homeLng!) : null,
        flexMinutes: settings.flexMinutes,
      );
    }
    return _week!;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final store = context.watch<StudentStore>();
    final settings = context.watch<SettingsStore>();
    final week = _weekFor(store, settings);

    return Scaffold(
      appBar: AppBar(title: Text(s.routine)),
      body: FutureBuilder<List<DayPlan>>(
        future: week,
        builder: (context, snap) {
          if (!snap.hasData) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(s.planning),
              ]),
            );
          }
          final plans = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              _SetupCard(settings: settings),
              const SizedBox(height: 12),
              if (plans.isEmpty)
                _EmptyRoutine()
              else ...[
                _WeekSummary(plans: plans, fare: settings.fare),
                const SizedBox(height: 12),
                _dayChips(plans),
                const SizedBox(height: 8),
                _DayView(
                  plan: plans.firstWhere(
                    (p) => p.weekday == _selectedDay,
                    orElse: () => plans.first,
                  ),
                  settings: settings,
                ),
                const SizedBox(height: 12),
                _aiCard(plans, store, settings),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _dayChips(List<DayPlan> plans) {
    final s = S.of(context);
    final selected = plans.any((p) => p.weekday == _selectedDay) ? _selectedDay : plans.first.weekday;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in plans)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${s.weekday(p.weekday)} · ${s.n(p.visits.length)}'),
                avatar: p.hasClash ? const Icon(Icons.warning_amber, size: 18) : null,
                selected: p.weekday == selected,
                onSelected: (_) => setState(() => _selectedDay = p.weekday),
              ),
            ),
        ],
      ),
    );
  }

  Widget _aiCard(List<DayPlan> plans, StudentStore store, SettingsStore settings) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final ai = settings.aiService();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(s.aiPlan, style: theme.textTheme.titleMedium)),
            ]),
            const SizedBox(height: 8),
            if (!ai.available)
              Text(s.aiNotSetUp)
            else ...[
              if (_aiBusy)
                Row(children: [
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text(s.aiThinking),
                ])
              else if (_aiText != null)
                SelectableText(_aiText!),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _aiBusy ? null : () => _askAi(ai, plans, store, settings),
                icon: const Icon(Icons.auto_awesome),
                label: Text(_aiText == null ? s.askAi : s.askAiAgain),
              ),
              const SizedBox(height: 4),
              Text(s.aiPrivacy, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _askAi(
      AiService ai, List<DayPlan> plans, StudentStore store, SettingsStore settings) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _aiBusy = true);
    try {
      final text = await ai.chat(RoutineAi.buildMessages(
        week: plans,
        students: store.current,
        bangla: settings.isBangla,
        flexMinutes: settings.flexMinutes,
      ));
      if (!mounted) return;
      setState(() => _aiText = text.trim());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastAiPlan', text.trim());
    } on AiNotConfigured {
      messenger.showSnackBar(SnackBar(content: Text(s.aiNotSetUp)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.aiFailed)));
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.home_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.startLocation, style: theme.textTheme.labelMedium),
                      Text(settings.hasHome
                          ? (settings.homeLabel.isEmpty ? s.locationPicked : settings.homeLabel)
                          : s.homeHelp),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _pickHome(context),
                  child: Text(settings.hasHome ? s.changeHome : s.setHome),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(s.flexibility, style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final m in const [0, 15, 30, 60])
                  ChoiceChip(
                    label: Text(m == 0 ? s.fixedTimes : s.minutesShort(m)),
                    selected: settings.flexMinutes == m,
                    onSelected: (_) => settings.setFlexMinutes(m),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickHome(BuildContext context) async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (picked != null) {
      await settings.setHome(picked.latLng.latitude, picked.latLng.longitude, picked.address);
    }
  }
}

class _EmptyRoutine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Icon(Icons.event_note_outlined, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        Text(s.routineEmptyTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(s.routineEmptyBody, textAlign: TextAlign.center),
      ]),
    );
  }
}

class _WeekSummary extends StatelessWidget {
  const _WeekSummary({required this.plans, required this.fare});

  final List<DayPlan> plans;
  final FareRates fare;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final classes = plans.fold(0, (n, p) => n + p.visits.length);
    final mins = plans.fold(0.0, (n, p) => n + p.travelMinutes);
    final cost = plans.fold(0.0, (n, p) => n + p.fare(fare));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.weekTotal, style: theme.textTheme.labelMedium),
                Text(s.classesCount(classes),
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              ]),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.travelTime, style: theme.textTheme.labelMedium),
                Text(s.minutes(mins),
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              ]),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.bikeFare, style: theme.textTheme.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(s.money(cost),
                    style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayView extends StatelessWidget {
  const _DayView({required this.plan, required this.settings});

  final DayPlan plan;
  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    Widget leg(double mins, double km, {String? label}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Row(children: [
            Icon(Icons.two_wheeler, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              [
                ?label,
                s.minutes(mins),
                s.km(km),
                s.money(settings.fare.estimate(km: km, minutes: mins)),
              ].join(' · '),
              style: muted,
            ),
          ]),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (plan.savedMinutes >= 1)
          Card(
            color: theme.colorScheme.primary.withValues(alpha: 0.10),
            child: ListTile(
              leading: Icon(Icons.savings_outlined, color: theme.colorScheme.primary),
              title: Text(s.savesMinutes(plan.savedMinutes)),
            ),
          ),
        const SizedBox(height: 8),
        for (final v in plan.visits) ...[
          if (v.travelKm > 0) leg(v.travelMinutes, v.travelKm),
          Card(
            child: ListTile(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => StudentDetailScreen(studentId: v.routine.student.id),
              )),
              leading: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(formatMinutes(context, v.start),
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(formatMinutes(context, v.end), style: muted),
                ],
              ),
              title: Text(v.routine.student.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (v.routine.student.address.isNotEmpty)
                    Text(v.routine.student.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (v.start != v.preferredStart)
                    Text(s.movedFrom(formatMinutes(context, v.preferredStart)), style: muted),
                  if (v.routine.inferred) Text(s.learnedFromHistory, style: muted),
                  if (v.clash)
                    Text(s.clashWarning, style: TextStyle(color: theme.colorScheme.error)),
                ],
              ),
              trailing: v.clash ? Icon(Icons.warning_amber, color: theme.colorScheme.error) : null,
            ),
          ),
        ],
        if (plan.returnKm > 0) leg(plan.returnMinutes, plan.returnKm, label: s.backHome),
        const SizedBox(height: 8),
        Text(plan.liveTraffic ? s.liveTimes : s.roughTimes, style: muted),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Launcher.dayRoute(
            home: settings.hasHome ? '${settings.homeLat},${settings.homeLng}' : null,
            stops: plan.visits.map((v) => v.routine.student).toList(),
          ),
          icon: const Icon(Icons.map_outlined),
          label: Text(s.openRoute),
        ),
      ],
    );
  }
}
