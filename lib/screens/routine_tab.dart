import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/student.dart';
import '../state/student_store.dart';

/// Weekly overview built from each student's schedule. The AI planner
/// (best order / least travel) will be added on top of this.
class RoutineTab extends StatelessWidget {
  const RoutineTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final students = context.watch<StudentStore>().current;
    final byDay = <int, List<(Student, WeeklySlot)>>{};
    for (final st in students) {
      for (final slot in st.schedule) {
        byDay.putIfAbsent(slot.weekday, () => []).add((st, slot));
      }
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.$2.startMinutes.compareTo(b.$2.startMinutes));
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.routine)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Card(
            child: ListTile(
              leading: Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
              title: Text(s.routineComingTitle),
              subtitle: Text(s.routineComingBody),
            ),
          ),
          const SizedBox(height: 12),
          // Bangladeshi week starts on Saturday.
          for (final wd in const [6, 7, 1, 2, 3, 4, 5])
            if (byDay[wd] case final slots?) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                child: Text(s.weekday(wd),
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
              ),
              Card(
                child: Column(
                  children: [
                    for (final (st, slot) in slots)
                      ListTile(
                        leading: Text(
                          TimeOfDay(hour: slot.startMinutes ~/ 60, minute: slot.startMinutes % 60)
                              .format(context),
                          style: theme.textTheme.titleSmall,
                        ),
                        title: Text(st.name),
                        subtitle: st.address.isEmpty ? null : Text(st.address, maxLines: 1),
                      ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}
