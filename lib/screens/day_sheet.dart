import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/student.dart';
import '../state/settings_store.dart';
import '../state/student_store.dart';

Future<void> showDaySheet(BuildContext context, String studentId, DateTime day) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, scroll) => DaySheet(studentId: studentId, day: day, scroll: scroll),
      ),
    );

/// One day: classes taught, notes/homework (with photos) and the previous
/// day's homework for reference.
class DaySheet extends StatelessWidget {
  const DaySheet({super.key, required this.studentId, required this.day, required this.scroll});

  final String studentId;
  final DateTime day;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final store = context.watch<StudentStore>();
    final st = store.byId(studentId);
    if (st == null) return const SizedBox();
    final locale = context.watch<SettingsStore>().locale.languageCode;
    final count = st.sessionsOn(day);
    final notes = st.notesOn(day);
    final prevDay = st.previousNoteDay(day);
    final isFuture = dateOnly(day).isAfter(dateOnly(DateTime.now()));

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(DateFormat.yMMMMEEEEd(locale).format(day), style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(count > 0 ? Icons.check_circle : Icons.radio_button_unchecked,
                color: count > 0 ? theme.colorScheme.primary : null),
            const SizedBox(width: 8),
            Expanded(child: Text(count > 0 ? s.classesOnDay(count) : s.notTaught)),
            if (count > 0)
              IconButton(
                tooltip: s.removeClass,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => store.removeSessionOnDay(st, day),
              ),
            if (!isFuture)
              FilledButton.tonalIcon(
                onPressed: () => store.addSession(st, _timeOn(day)),
                icon: const Icon(Icons.add),
                label: Text(s.markTaught),
              ),
          ],
        ),
        const Divider(height: 32),
        Row(
          children: [
            Expanded(child: Text(s.homework, style: theme.textTheme.titleMedium)),
            FilledButton.icon(
              onPressed: () => _addNote(context, st),
              icon: const Icon(Icons.note_add_outlined),
              label: Text(s.addNote),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (notes.isEmpty) Text(s.noNotes),
        for (final n in notes) _NoteTile(student: st, note: n, deletable: true),
        if (prevDay != null) ...[
          const Divider(height: 32),
          Text(s.previousHomework(DateFormat.yMMMd(locale).format(prevDay)),
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final n in st.notesOn(prevDay)) _NoteTile(student: st, note: n, deletable: false),
        ],
      ],
    );
  }

  /// A class added from the calendar is stamped at noon of that day, or now
  /// if the day is today, so it sorts correctly against payments.
  DateTime _timeOn(DateTime d) {
    final now = DateTime.now();
    if (dateOnly(d) == dateOnly(now)) return now;
    return DateTime(d.year, d.month, d.day, 12);
  }

  Future<void> _addNote(BuildContext context, Student st) async {
    final store = context.read<StudentStore>();
    final result = await showDialog<_NoteResult>(
      context: context,
      builder: (_) => const _NoteDialog(),
    );
    if (result == null) return;
    if (result.text.trim().isEmpty && result.newImages.isEmpty) return;
    await store.addNote(st, day, result.text, result.newImages);
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.student, required this.note, required this.deletable});

  final Student student;
  final DayNote note;
  final bool deletable;

  Future<void> _edit(BuildContext context) async {
    final store = context.read<StudentStore>();
    final result = await showDialog<_NoteResult>(
      context: context,
      builder: (_) => _NoteDialog(existing: note),
    );
    if (result == null) return;
    await store.updateNote(student, note, result.text, result.keptImages, result.newImages);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<StudentStore>();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(note.text)),
                if (deletable)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: S.of(context).editNote,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _edit(context),
                  ),
                if (deletable)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: S.of(context).delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => store.deleteNote(student, note),
                  ),
              ],
            ),
            if (note.imagePaths.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: note.imagePaths.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final file = store.imageFile(note.imagePaths[i]);
                    return GestureDetector(
                      onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
                        builder: (_) => Scaffold(
                          backgroundColor: Colors.black,
                          appBar: AppBar(
                              backgroundColor: Colors.black, foregroundColor: Colors.white),
                          body: Center(child: InteractiveViewer(child: Image.file(file))),
                        ),
                      )),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(file, width: 96, height: 96, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(
                                width: 96, height: 96, child: Icon(Icons.broken_image_outlined))),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoteResult {
  const _NoteResult(this.text, this.keptImages, this.newImages);

  final String text;

  /// Saved photo names the teacher kept (when editing).
  final List<String> keptImages;

  /// Paths of newly picked photos.
  final List<String> newImages;
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({this.existing});

  final DayNote? existing;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _text = TextEditingController(text: widget.existing?.text);
  late final _kept = [...?widget.existing?.imagePaths];
  final _images = <XFile>[];
  final _picker = ImagePicker();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (source == ImageSource.camera) {
      final img = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1920);
      if (img != null) setState(() => _images.add(img));
    } else {
      final imgs = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1920);
      setState(() => _images.addAll(imgs));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final store = context.read<StudentStore>();
    Widget thumb(Widget image, VoidCallback onRemove) => Stack(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: image),
            Positioned(
              right: 0,
              top: 0,
              child: InkWell(
                onTap: onRemove,
                child: const CircleAvatar(
                    radius: 12, backgroundColor: Colors.black54,
                    child: Icon(Icons.close, size: 14, color: Colors.white)),
              ),
            ),
          ],
        );
    return AlertDialog(
      title: Text(widget.existing == null ? s.addNote : s.editNote),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _text,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(hintText: s.writeNote),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(s.camera),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(s.gallery),
                  ),
                ),
              ],
            ),
            if (_kept.isNotEmpty || _images.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in _kept)
                    thumb(
                      Image.file(store.imageFile(name), width: 64, height: 64, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(width: 64, height: 64)),
                      () => setState(() => _kept.remove(name)),
                    ),
                  for (final x in _images)
                    thumb(
                      Image.file(File(x.path), width: 64, height: 64, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(width: 64, height: 64)),
                      () => setState(() => _images.remove(x)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _NoteResult(_text.text, _kept, _images.map((x) => x.path).toList()),
          ),
          child: Text(s.save),
        ),
      ],
    );
  }
}
