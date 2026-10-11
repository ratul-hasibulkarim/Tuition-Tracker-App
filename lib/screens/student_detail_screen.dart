import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../l10n/strings.dart';
import '../models/student.dart';
import '../services/launcher.dart';
import '../state/settings_store.dart';
import '../state/student_store.dart';
import '../widgets/trip_sheet.dart';
import '../utils/format.dart';
import 'day_sheet.dart';
import 'student_form_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({super.key, required this.studentId});

  final String studentId;

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  bool _showMore = false;
  DateTime _focused = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<StudentStore>().byId(widget.studentId);
    if (st == null) return const Scaffold();
    final theme = Theme.of(context);
    final locale = context.watch<SettingsStore>().locale.languageCode;
    final dateFmt = DateFormat.yMMMd(locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(st.name),
        actions: [
          IconButton(
            tooltip: s.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(st),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => v == 'archive' ? _toggleArchive(st) : _delete(st),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'archive', child: Text(st.archived ? s.unarchive : s.archive)),
              PopupMenuItem(value: 'delete', child: Text(s.delete)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addClassToday(st),
        icon: const Icon(Icons.add),
        label: Text(s.addClass),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          // Summary: location, counter and quick actions.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place_outlined, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(child: Text(st.address.isEmpty ? s.noLocation : st.address)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(s.daysSincePayment(st.sessionsSinceLastPayment),
                      style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: st.callNumber.isEmpty ? null : () => Launcher.call(st.callNumber),
                        icon: const Icon(Icons.call),
                        label: Text(s.call),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => showTripSheet(context, st),
                        icon: const Icon(Icons.directions_bike),
                        label: Text(s.directions),
                      ),
                      if (st.whatsapp.isNotEmpty)
                        FilledButton.tonalIcon(
                          onPressed: () => Launcher.whatsapp(st.whatsapp),
                          icon: const Icon(Icons.chat),
                          label: Text(s.whatsapp),
                        ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _showMore = !_showMore),
                    icon: Icon(_showMore ? Icons.expand_less : Icons.expand_more),
                    label: Text(_showMore ? s.hideDetails : s.showDetails),
                  ),
                  if (_showMore) _MoreDetails(student: st, onEdit: () => _edit(st)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Metrics
          Row(
            children: [
              _Metric(label: s.totalClasses, value: s.n(st.totalSessions)),
              const SizedBox(width: 8),
              _Metric(label: s.totalReceived, value: s.money(st.totalReceived)),
              const SizedBox(width: 8),
              _Metric(
                label: s.lastPayment,
                value: st.lastPaymentDate == null ? s.never : dateFmt.format(st.lastPaymentDate!),
              ),
            ],
          ),
          if (_dueEstimate(st) case final due?) ...[
            const SizedBox(height: 8),
            Row(children: [
              _Metric(label: s.dueEstimate, value: s.money(due)),
            ]),
          ],
          const SizedBox(height: 12),

          // Calendar
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Column(
                children: [
                  Text(s.calendar, style: theme.textTheme.titleMedium),
                  TableCalendar<int>(
                    locale: locale,
                    focusedDay: _focused,
                    firstDay: DateTime(2015),
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    startingDayOfWeek: StartingDayOfWeek.saturday,
                    weekendDays: const [DateTime.friday],
                    availableCalendarFormats: const {CalendarFormat.month: ''},
                    headerStyle: const HeaderStyle(titleCentered: true, formatButtonVisible: false),
                    eventLoader: (day) => List.filled(st.sessionsOn(day), 0),
                    onPageChanged: (d) => setState(() => _focused = d),
                    onDaySelected: (day, focused) {
                      setState(() => _focused = focused);
                      showDaySheet(context, st.id, day);
                    },
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (ctx, day, _) => _dayCell(ctx, st, day, false),
                      todayBuilder: (ctx, day, _) => _dayCell(ctx, st, day, true),
                      markerBuilder: (ctx, day, events) {
                        final hasNotes = st.notesOn(day).isNotEmpty;
                        if (!hasNotes && events.length < 2) return null;
                        return Positioned(
                          bottom: 2,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (events.length > 1)
                              Text('×${s.n(events.length)}', style: theme.textTheme.labelSmall),
                            if (hasNotes)
                              Icon(Icons.sticky_note_2, size: 10, color: theme.colorScheme.tertiary),
                          ]),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(s.classesThisMonth(st.sessionsInMonth(_focused.year, _focused.month))),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Payments
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(s.payments, style: theme.textTheme.titleMedium)),
                      FilledButton.icon(
                        onPressed: () => _recordPayment(st),
                        icon: const Icon(Icons.payments_outlined),
                        label: Text(s.recordPayment),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (st.payments.isEmpty)
                    Text(s.noPayments)
                  else
                    for (final p in st.payments.reversed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => _editPayment(st, p),
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(s.money(p.amount)),
                        subtitle: Text([dateFmt.format(p.date), if (p.note.isNotEmpty) p.note].join(' · ')),
                        trailing: IconButton(
                          tooltip: s.delete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => context.read<StudentStore>().removePayment(st, p),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fee owed for classes since last payment, when fee and classes/month are set.
  double? _dueEstimate(Student st) {
    final fee = st.monthlyFee;
    final cycle = st.daysPerCycle;
    if (fee == null || cycle == null || cycle == 0) return null;
    return fee * st.sessionsSinceLastPayment / cycle;
  }

  Widget _dayCell(BuildContext ctx, Student st, DateTime day, bool today) {
    final theme = Theme.of(ctx);
    final taught = st.sessionsOn(day) > 0;
    return Container(
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: taught ? theme.colorScheme.primary : null,
        shape: BoxShape.circle,
        border: today ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
      ),
      child: Text(
        S.of(ctx).n(day.day),
        style: TextStyle(
          color: taught ? theme.colorScheme.onPrimary : null,
          fontWeight: taught || today ? FontWeight.w700 : null,
        ),
      ),
    );
  }

  void _edit(Student st) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StudentFormScreen(student: st)),
      );

  Future<void> _addClassToday(Student st) async {
    final s = S.of(context);
    final store = context.read<StudentStore>();
    final messenger = ScaffoldMessenger.of(context);
    final t = await store.addSession(st);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(s.classAdded(st.name)),
        action: SnackBarAction(label: s.undo, onPressed: () => store.removeSession(st, t)),
      ));
  }

  Future<void> _toggleArchive(Student st) async {
    await context.read<StudentStore>().setArchived(st, !st.archived);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete(Student st) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteConfirmTitle),
        content: Text(s.deleteConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.delete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final store = context.read<StudentStore>();
    Navigator.of(context).pop();
    await store.delete(st);
  }

  Future<void> _editPayment(Student st, Payment p) async {
    final edited = await showDialog<Payment>(
      context: context,
      builder: (_) => _PaymentDialog(existing: p),
    );
    if (edited != null && mounted) {
      await context.read<StudentStore>().updatePayment(st, edited);
    }
  }

  Future<void> _recordPayment(Student st) async {
    final payment = await showDialog<Payment>(
      context: context,
      builder: (_) => _PaymentDialog(defaultAmount: st.monthlyFee),
    );
    if (payment != null && mounted) {
      await context.read<StudentStore>().addPayment(st, payment);
    }
  }
}

class _MoreDetails extends StatelessWidget {
  const _MoreDetails({required this.student, required this.onEdit});

  final Student student;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = student;
    Widget row(IconData icon, String label, String value, {VoidCallback? onTap}) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(label),
          subtitle: Text(value),
          trailing: onTap == null ? null : const Icon(Icons.call_outlined),
          onTap: onTap,
        );
    final phones = <(IconData, String, String)>[
      (Icons.phone_android, s.studentPhone, st.studentPhone),
      (Icons.chat_outlined, s.whatsapp, st.whatsapp),
      (Icons.man_outlined, s.fatherPhone, st.fatherPhone),
      (Icons.woman_outlined, s.motherPhone, st.motherPhone),
    ];
    final schedule = st.schedule
        .map((x) =>
            '${s.weekday(x.weekday)} ${formatMinutes(context, x.startMinutes)}')
        .join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (st.className.isNotEmpty) row(Icons.class_outlined, s.classLabel, st.className),
        if (st.subjects.isNotEmpty) row(Icons.menu_book_outlined, s.subjectsLabel, st.subjects),
        for (final (icon, label, number) in phones)
          if (number.isNotEmpty) row(icon, label, number, onTap: () => Launcher.call(number)),
        row(Icons.star_outline, s.defaultCallNumber, s.contactLabel(st.defaultContact.name)),
        if (st.monthlyFee != null)
          row(Icons.payments_outlined, s.monthlyFee, s.money(st.monthlyFee!)),
        if (st.daysPerCycle != null)
          row(Icons.event_repeat, s.daysPerCycle, s.n(st.daysPerCycle!)),
        if (schedule.isNotEmpty) row(Icons.schedule, s.weeklySchedule, schedule),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: Text(s.edit),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(value,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({this.defaultAmount, this.existing});

  final double? defaultAmount;

  /// When set, the dialog edits this payment instead of creating one.
  final Payment? existing;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final _amount = TextEditingController(
      text: _fmtAmount(widget.existing?.amount ?? widget.defaultAmount));
  late final _note = TextEditingController(text: widget.existing?.note);
  late DateTime _date = widget.existing?.date ?? DateTime.now();

  static String _fmtAmount(double? v) =>
      v == null ? '' : (v == v.roundToDouble() ? v.round().toString() : v.toString());
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final locale = context.watch<SettingsStore>().locale.languageCode;
    return AlertDialog(
      title: Text(widget.existing == null ? s.recordPayment : s.editPayment),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: s.amount, errorText: _error),
          ),
          const SizedBox(height: 12),
          TextField(controller: _note, decoration: InputDecoration(labelText: s.note)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text(DateFormat.yMMMd(locale).format(_date)),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2015),
                lastDate: DateTime.now(),
              );
              if (d != null) {
                // Keep "now" as the time for today so classes earlier today
                // count as paid; past dates count up to the end of that day.
                final now = DateTime.now();
                setState(() => _date = dateOnly(d) == dateOnly(now)
                    ? now
                    : DateTime(d.year, d.month, d.day, 23, 59, 59));
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: () {
            final v = double.tryParse(_amount.text.trim());
            if (v == null || v <= 0) {
              setState(() => _error = s.invalidNumber);
              return;
            }
            Navigator.pop(
              context,
              Payment(id: widget.existing?.id, date: _date, amount: v, note: _note.text.trim()),
            );
          },
          child: Text(s.save),
        ),
      ],
    );
  }
}
