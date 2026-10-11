import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/student.dart';
import '../state/settings_store.dart';
import '../state/student_store.dart';
import '../widgets/student_card.dart';
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

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final store = context.watch<StudentStore>();
    final settings = context.watch<SettingsStore>();
    final source = _showPast ? store.archived : store.current;
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
          if (store.archived.isNotEmpty || _showPast)
            IconButton(
              tooltip: _showPast ? s.currentTuitions : s.pastTuitions,
              icon: Icon(_showPast ? Icons.school_outlined : Icons.history),
              onPressed: () => setState(() => _showPast = !_showPast),
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
