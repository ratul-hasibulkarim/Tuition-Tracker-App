import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/student_repository.dart';
import '../models/student.dart';

class StudentStore extends ChangeNotifier {
  StudentStore(this._repo);

  final StudentRepository _repo;
  final List<Student> _students = [];
  String _imagesPath = '';
  bool loaded = false;

  /// Bumps on every change, so screens can tell when to recompute.
  int revision = 0;
  DateTime? lastChanged;

  List<Student> get all => List.unmodifiable(_students);

  List<Student> get current =>
      _students.where((s) => !s.archived).toList()..sort(_byName);

  List<Student> get archived =>
      _students.where((s) => s.archived).toList()..sort(_byName);

  static int _byName(Student a, Student b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  /// Batch names in use by current students, for coaching centres.
  List<String> get batches {
    final names = _students
        .where((s) => !s.archived && s.batch.trim().isNotEmpty)
        .map((s) => s.batch.trim())
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  List<Student> inBatch(String batch) =>
      current.where((s) => s.batch.trim() == batch).toList();

  Student? byId(String id) {
    for (final s in _students) {
      if (s.id == id) return s;
    }
    return null;
  }

  File imageFile(String name) => File('$_imagesPath/$name');

  Future<void> load() async {
    _students
      ..clear()
      ..addAll(await _repo.load());
    _imagesPath = (await _repo.imagesDir()).path;
    loaded = true;
    revision++;
    notifyListeners();
  }

  Future<void> _commit() async {
    revision++;
    lastChanged = DateTime.now();
    notifyListeners();
    await _repo.save(_students);
  }

  Future<void> upsert(Student s) async {
    final i = _students.indexWhere((x) => x.id == s.id);
    if (i >= 0) {
      _students[i] = s;
    } else {
      _students.add(s);
    }
    await _commit();
  }

  /// Saves several new students at once (e.g. a whole coaching batch).
  Future<void> addMany(List<Student> students) async {
    _students.addAll(students);
    await _commit();
  }

  Future<void> delete(Student s) async {
    for (final n in s.notes) {
      for (final img in n.imagePaths) {
        await _repo.deleteImage(img);
      }
    }
    _students.removeWhere((x) => x.id == s.id);
    await _commit();
  }

  Future<void> setArchived(Student s, bool value) async {
    s.archived = value;
    await _commit();
  }

  /// The "+" button: records one class taught at [when] (default now).
  Future<DateTime> addSession(Student s, [DateTime? when]) async {
    final t = when ?? DateTime.now();
    s.sessions.add(t);
    s.sessions.sort();
    await _commit();
    return t;
  }

  /// One class for every student in [group]; returns the shared timestamp.
  Future<DateTime> addSessionForAll(List<Student> group) async {
    final t = DateTime.now();
    for (final s in group) {
      s.sessions
        ..add(t)
        ..sort();
    }
    await _commit();
    return t;
  }

  Future<void> removeSessionForAll(List<Student> group, DateTime t) async {
    for (final s in group) {
      s.sessions.remove(t);
    }
    await _commit();
  }

  Future<void> addPayments(Map<Student, Payment> payments) async {
    payments.forEach((s, p) {
      s.payments
        ..add(p)
        ..sort((a, b) => a.date.compareTo(b.date));
    });
    await _commit();
  }

  Future<void> removeSession(Student s, DateTime t) async {
    s.sessions.remove(t);
    await _commit();
  }

  /// Removes the most recent class recorded on [day].
  Future<void> removeSessionOnDay(Student s, DateTime day) async {
    final d = dateOnly(day);
    final onDay = s.sessions.where((x) => dateOnly(x) == d).toList();
    if (onDay.isEmpty) return;
    s.sessions.remove(onDay.last);
    await _commit();
  }

  Future<void> addPayment(Student s, Payment p) async {
    s.payments.add(p);
    s.payments.sort((a, b) => a.date.compareTo(b.date));
    await _commit();
  }

  /// Replaces a saved payment (matched by id) with edited values.
  Future<void> updatePayment(Student s, Payment edited) async {
    final i = s.payments.indexWhere((x) => x.id == edited.id);
    if (i < 0) return;
    s.payments[i] = edited;
    s.payments.sort((a, b) => a.date.compareTo(b.date));
    await _commit();
  }

  Future<void> removePayment(Student s, Payment p) async {
    s.payments.removeWhere((x) => x.id == p.id);
    await _commit();
  }

  Future<void> addNote(Student s, DateTime day, String text, List<String> pickedImagePaths) async {
    final names = <String>[];
    for (final path in pickedImagePaths) {
      names.add(await _repo.importImage(path));
    }
    s.notes.add(DayNote(date: dateOnly(day), text: text.trim(), imagePaths: names));
    await _commit();
  }

  /// Edits a note: new text, the photos kept, and newly picked photos.
  Future<void> updateNote(Student s, DayNote n, String text, List<String> keptImages,
      List<String> pickedImagePaths) async {
    final i = s.notes.indexWhere((x) => x.id == n.id);
    if (i < 0) return;
    for (final img in n.imagePaths) {
      if (!keptImages.contains(img)) await _repo.deleteImage(img);
    }
    final names = [...keptImages];
    for (final path in pickedImagePaths) {
      names.add(await _repo.importImage(path));
    }
    s.notes[i] = DayNote(
      id: n.id,
      date: n.date,
      text: text.trim(),
      imagePaths: names,
      createdAt: n.createdAt,
    );
    await _commit();
  }

  Future<void> deleteNote(Student s, DayNote n) async {
    for (final img in n.imagePaths) {
      await _repo.deleteImage(img);
    }
    s.notes.removeWhere((x) => x.id == n.id);
    await _commit();
  }
}
