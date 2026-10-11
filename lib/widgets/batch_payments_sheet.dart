import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/student.dart';
import '../state/student_store.dart';

/// Record this month's payments for many students in a batch at once.
class BatchPaymentsSheet extends StatefulWidget {
  const BatchPaymentsSheet({super.key, required this.students});

  final List<Student> students;

  @override
  State<BatchPaymentsSheet> createState() => _BatchPaymentsSheetState();
}

class _BatchPaymentsSheetState extends State<BatchPaymentsSheet> {
  late final Map<String, TextEditingController> _amounts = {
    for (final st in widget.students)
      st.id: TextEditingController(text: st.monthlyFee == null ? '' : st.monthlyFee!.round().toString()),
  };
  final Set<String> _selected = {};

  @override
  void dispose() {
    for (final c in _amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final s = S.of(context);
    final store = context.read<StudentStore>();
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final payments = <Student, Payment>{};
    for (final st in widget.students) {
      if (!_selected.contains(st.id)) continue;
      final v = double.tryParse(_amounts[st.id]!.text.trim());
      if (v == null || v <= 0) continue;
      payments[st] = Payment(date: now, amount: v);
    }
    if (payments.isEmpty) return;
    await store.addPayments(payments);
    messenger.showSnackBar(SnackBar(content: Text(s.paymentsSaved(payments.length))));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.batchPayments, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final st in widget.students)
                    Row(
                      children: [
                        Checkbox(
                          value: _selected.contains(st.id),
                          onChanged: (v) => setState(() =>
                              v == true ? _selected.add(st.id) : _selected.remove(st.id)),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(st.name),
                              Text(s.daysSincePayment(st.sessionsSinceLastPayment),
                                  style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: _amounts[st.id],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(prefixText: '৳ ', isDense: true),
                            onChanged: (_) => setState(() => _selected.add(st.id)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _selected.isEmpty ? null : _save,
              child: Text('${s.save} (${s.n(_selected.length)})'),
            ),
          ],
        ),
      ),
    );
  }
}
