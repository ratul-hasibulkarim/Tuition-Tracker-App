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

  List<Student> get all => List.unmodifiable(_students);

  List<Student> get current =>
      _students.where((s) => !s.archived).toList()..sort(_byName);

  List<Student> get archived =>
      _students.where((s) => s.archived).toList()..sort(_byName);

  static int _byName(Student a, Student b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

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
    notifyListeners();
  }

  Future<void> _commit() async {
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

  Future<void> deleteNote(Student s, DayNote n) async {
    for (final img in n.imagePaths) {
      await _repo.deleteImage(img);
    }
    s.notes.removeWhere((x) => x.id == n.id);
    await _commit();
  }
}
