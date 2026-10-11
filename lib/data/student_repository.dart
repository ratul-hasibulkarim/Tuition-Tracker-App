import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/student.dart';

/// Stores all students in one JSON file on the phone.
///
/// A single file keeps backup/restore (e.g. to Google Drive) simple:
/// upload `students.json` plus the `images/` folder.
class StudentRepository {
  // ignore: prefer_initializing_formals
  StudentRepository({Directory? baseDir}) : _baseDir = baseDir;

  static const schemaVersion = 1;
  Directory? _baseDir;

  Future<Directory> get baseDir async =>
      _baseDir ??= await getApplicationDocumentsDirectory();

  Future<File> get _file async => File('${(await baseDir).path}/students.json');

  Future<Directory> imagesDir() async {
    final dir = Directory('${(await baseDir).path}/images');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<Student>> load() async {
    final file = await _file;
    if (!await file.exists()) return [];
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return (data['students'] as List? ?? [])
        .map((s) => Student.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<Student> students) async {
    final file = await _file;
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode({
      'schemaVersion': schemaVersion,
      'savedAt': DateTime.now().toIso8601String(),
      'students': students.map((s) => s.toJson()).toList(),
    }));
    // Write-then-rename so a crash mid-save never corrupts the data file.
    await tmp.rename(file.path);
  }

  /// Copies a picked image into app storage so it survives cache clears.
  /// Returns the file name only: absolute paths change on iOS between
  /// app updates, so names are resolved against [imagesDir] when shown.
  Future<String> importImage(String sourcePath) async {
    final dir = await imagesDir();
    final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'jpg';
    final name = '${newId()}.$ext';
    await File(sourcePath).copy('${dir.path}/$name');
    return name;
  }

  Future<void> deleteImage(String name) async {
    final f = File('${(await imagesDir()).path}/$name');
    if (await f.exists()) await f.delete();
  }
}
