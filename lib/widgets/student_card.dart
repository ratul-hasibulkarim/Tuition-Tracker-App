import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/student.dart';
import '../services/launcher.dart';
import '../state/student_store.dart';
import 'trip_sheet.dart';

/// Shows name, area, classes since last payment and quick actions:
/// call, directions/fare, and "+" to record a class.
class StudentCard extends StatelessWidget {
  const StudentCard({
    super.key,
    required this.student,
    required this.compact,
    required this.onOpen,
  });

  final Student student;
  final bool compact;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final count = student.sessionsSinceLastPayment;
    final cycle = student.daysPerCycle;
    final due = cycle != null && count >= cycle;

    final counter = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (due ? theme.colorScheme.error : theme.colorScheme.primary)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cycle == null ? '$count' : '$count/$cycle',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: due ? theme.colorScheme.error : theme.colorScheme.primary,
            ),
          ),
          Text(s.daysShort, style: theme.textTheme.labelSmall),
        ],
      ),
    );

    final title = Text(
      student.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );

    final location = Row(
      children: [
        Icon(Icons.place_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            student.address.isEmpty ? s.noLocation : student.address,
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );

    final actions = Row(
      mainAxisAlignment: compact ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
      children: [
        IconButton.outlined(
          tooltip: s.call,
          icon: const Icon(Icons.call_outlined),
          onPressed: () => _call(context),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: s.directions,
          icon: const Icon(Icons.directions_bike_outlined),
          onPressed: () => showTripSheet(context, student),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: s.addClass,
          icon: const Icon(Icons.add),
          onPressed: () => _addClass(context),
        ),
      ],
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Expanded(child: title), counter]),
                    const SizedBox(height: 8),
                    location,
                    const Spacer(),
                    actions,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        counter,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [title, const SizedBox(height: 4), location],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    actions,
                  ],
                ),
        ),
      ),
    );
  }

  void _call(BuildContext context) {
    final number = student.callNumber;
    if (number.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.of(context).noPhone)));
      return;
    }
    Launcher.call(number);
  }

  Future<void> _addClass(BuildContext context) async {
    final s = S.of(context);
    final store = context.read<StudentStore>();
    final messenger = ScaffoldMessenger.of(context);
    final t = await store.addSession(student);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(s.classAdded(student.name)),
        action: SnackBarAction(
          label: s.undo,
          onPressed: () => store.removeSession(student, t),
        ),
      ));
  }
}
