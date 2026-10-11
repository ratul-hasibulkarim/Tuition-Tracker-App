import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/student.dart';
import '../state/student_store.dart';
import 'student_detail_screen.dart';

/// Money received across all students, month by month.
class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class IncomeMonth {
  IncomeMonth(this.year, this.month, List<Student> students)
      : byStudent = {
          for (final st in students)
            if (_sum(st, year, month) > 0) st: _sum(st, year, month),
        },
        classes = students.fold(0, (n, st) => n + st.sessionsInMonth(year, month));

  final int year;
  final int month;
  final Map<Student, double> byStudent;
  final int classes;

  double get total => byStudent.values.fold(0.0, (a, b) => a + b);

  static double _sum(Student st, int year, int month) => st.payments
      .where((p) => p.date.year == year && p.date.month == month)
      .fold(0.0, (a, p) => a + p.amount);
}

class _IncomeScreenState extends State<IncomeScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final store = context.watch<StudentStore>();
    final locale = Localizations.localeOf(context).languageCode;
    final all = store.all;
    final current = IncomeMonth(_month.year, _month.month, all);
    final expected = store.current.fold(0.0, (a, st) => a + (st.monthlyFee ?? 0));
    final allTime = all.fold(0.0, (a, st) => a + st.totalReceived);
    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;
    final history = [
      for (var i = 5; i >= 0; i--)
        IncomeMonth(DateTime(_month.year, _month.month - i).year,
            DateTime(_month.year, _month.month - i).month, all),
    ];
    final maxTotal = history.fold(0.0, (a, m) => m.total > a ? m.total : a);
    final rows = current.byStudent.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    Widget stat(String label, String value, {bool accent = false}) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: theme.textTheme.labelMedium, maxLines: 2),
                const SizedBox(height: 4),
                Text(value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accent ? theme.colorScheme.primary : null,
                    )),
              ]),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.incomeSummary)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
              Expanded(
                child: Text(DateFormat.yMMMM(locale).format(_month),
                    textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: isCurrentMonth ? null : () => _shift(1),
              ),
            ],
          ),
          Row(children: [
            stat(s.receivedThisMonth, s.money(current.total), accent: true),
            const SizedBox(width: 8),
            stat(s.classesTaught, s.n(current.classes)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            stat(s.expectedMonthly, s.money(expected)),
            const SizedBox(width: 8),
            stat(s.allTime, s.money(allTime)),
          ]),
          const SizedBox(height: 16),
          Text(s.lastSixMonths, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              child: SizedBox(
                height: 160,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final m in history)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                m.total == 0 ? '' : s.n(_short(m.total)),
                                style: theme.textTheme.labelSmall,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: maxTotal == 0 ? 2 : 2 + 100 * m.total / maxTotal,
                                decoration: BoxDecoration(
                                  color: m.month == _month.month && m.year == _month.year
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.primary.withValues(alpha: 0.35),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(DateFormat.MMM(locale).format(DateTime(m.year, m.month)),
                                  style: theme.textTheme.labelSmall, maxLines: 1),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(s.byStudent, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: rows.isEmpty
                ? ListTile(title: Text(s.noIncome))
                : Column(
                    children: [
                      for (final e in rows)
                        ListTile(
                          title: Text(e.key.name),
                          subtitle: e.key.batch.isEmpty ? null : Text(e.key.batch),
                          trailing: Text(s.money(e.value),
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => StudentDetailScreen(studentId: e.key.id),
                          )),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// 12500 → "12.5k" for bar labels.
  static String _short(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k' : v.round().toString();
}
