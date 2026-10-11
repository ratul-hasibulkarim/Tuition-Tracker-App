import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/student.dart';
import '../state/settings_store.dart';
import '../state/student_store.dart';
import '../widgets/batch_payments_sheet.dart';
import '../widgets/student_card.dart';
import 'add_several_screen.dart';
import 'income_screen.dart';
import 'student_detail_screen.dart';
import 'student_form_screen.dart';

class TuitionsTab extends StatefulWidget {
  const TuitionsTab({super.key});

  @override
  State<TuitionsTab> createState() => _TuitionsTabState();
}

class _TuitionsTabState extends State<TuitionsTab> {
  String _query = '';
  bool _showPast = false;

  /// Selected coaching batch filter; null = all students.
  String? _batch;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final store = context.watch<StudentStore>();
    final settings = context.watch<SettingsStore>();
    final batches = _showPast ? const <String>[] : store.batches;
    if (_batch != null && !batches.contains(_batch)) _batch = null;
    final source = _showPast
        ? store.archived
        : (_batch == null ? store.current : store.inBatch(_batch!));
    final q = _query.trim().toLowerCase();
    final students = q.isEmpty
        ? source
        : source
            .where((x) =>
                x.name.toLowerCase().contains(q) || x.address.toLowerCase().contains(q))
            .toList();
    final grid = settings.viewMode == ViewMode.grid;

    return Scaffold(
      appBar: AppBar(
        title: Text(_showPast ? s.pastTuitions : s.currentTuitions),
        actions: [
          IconButton(
            tooltip: grid ? s.listView : s.gridView,
            icon: Icon(grid ? Icons.view_agenda_outlined : Icons.grid_view_outlined),
            onPressed: () =>
                settings.setViewMode(grid ? ViewMode.list : ViewMode.grid),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              final nav = Navigator.of(context);
              switch (v) {
                case 'income':
                  nav.push(MaterialPageRoute(builder: (_) => const IncomeScreen()));
                case 'several':
                  nav.push(MaterialPageRoute(builder: (_) => const AddSeveralScreen()));
                case 'past':
                  setState(() => _showPast = !_showPast);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'income',
                child: ListTile(leading: const Icon(Icons.bar_chart), title: Text(s.incomeSummary)),
              ),
              PopupMenuItem(
                value: 'several',
                child: ListTile(leading: const Icon(Icons.group_add_outlined), title: Text(s.addSeveral)),
              ),
              if (store.archived.isNotEmpty || _showPast)
                PopupMenuItem(
                  value: 'past',
                  child: ListTile(
                    leading: Icon(_showPast ? Icons.school_outlined : Icons.history),
                    title: Text(_showPast ? s.currentTuitions : s.pastTuitions),
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: _showPast
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StudentFormScreen()),
              ),
              icon: const Icon(Icons.add),
              label: Text(s.addTuition),
            ),
      body: !store.loaded
          ? const Center(child: CircularProgressIndicator())
          : source.isEmpty
              ? _EmptyState(showPast: _showPast)
              : Column(
                  children: [
                    if (batches.isNotEmpty) _batchChips(batches),
                    if (_batch != null) _batchBar(source),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: s.searchHint,
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    Expanded(child: grid ? _grid(students) : _list(students)),
                  ],
                ),
    );
  }

  Widget _batchChips(List<String> batches) {
    final s = S.of(context);
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(s.all),
              selected: _batch == null,
              onSelected: (_) => setState(() => _batch = null),
            ),
          ),
          for (final b in batches)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: const Icon(Icons.groups_outlined, size: 18),
                label: Text(b),
                selected: _batch == b,
                onSelected: (_) => setState(() => _batch = b),
              ),
            ),
        ],
      ),
    );
  }

  /// Whole-batch actions for coaching centres.
  Widget _batchBar(List<Student> group) {
    final s = S.of(context);
    final store = context.read<StudentStore>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const SizedBox(width: 8),
              Expanded(child: Text(s.batchStudents(group.length))),
              TextButton.icon(
                onPressed: group.isEmpty
                    ? null
                    : () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => BatchPaymentsSheet(students: group),
                        ),
                icon: const Icon(Icons.payments_outlined),
                label: Text(s.batchPayments),
              ),
              FilledButton.icon(
                onPressed: group.isEmpty
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final t = await store.addSessionForAll(group);
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(
                            content: Text(s.classAddedForBatch(group.length)),
                            action: SnackBarAction(
                              label: s.undo,
                              onPressed: () => store.removeSessionForAll(group, t),
                            ),
                          ));
                      },
                icon: const Icon(Icons.add),
                label: Text(s.classForAll),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(Student st) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StudentDetailScreen(studentId: st.id)),
      );

  Widget _list(List<Student> students) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        itemCount: students.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => StudentCard(
          student: students[i],
          compact: false,
          onOpen: () => _open(students[i]),
        ),
      );

  Widget _grid(List<Student> students) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 210,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: students.length,
        itemBuilder: (_, i) => StudentCard(
          student: students[i],
          compact: true,
          onOpen: () => _open(students[i]),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.showPast});

  final bool showPast;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(s.noTuitionsTitle, style: theme.textTheme.titleLarge),
            if (!showPast) ...[
              const SizedBox(height: 8),
              Text(s.noTuitionsBody, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
