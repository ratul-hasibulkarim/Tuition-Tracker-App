import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/backup_archive.dart';
import '../data/student_repository.dart';
import '../services/drive_backup.dart';
import 'student_store.dart';

/// Google sign-in state and Drive backup/restore for the Settings screen.
class BackupStore extends ChangeNotifier {
  BackupStore(this._repo, this._students, {DriveBackup? drive})
      : _drive = drive ?? DriveBackup();

  static const autoBackupEvery = Duration(hours: 24);

  final StudentRepository _repo;
  final StudentStore _students;
  final DriveBackup _drive;

  String? email;
  DateTime? lastBackup;
  bool busy = false;
  String? error;

  bool get signedIn => email != null;

  /// Restores a previous sign-in silently, then backs up if one is due.
  Future<void> start() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('lastBackup');
    lastBackup = saved == null ? null : DateTime.tryParse(saved);
    try {
      final acc = await _drive.restoreSession();
      email = acc?.email;
      notifyListeners();
      if (signedIn &&
          (lastBackup == null || DateTime.now().difference(lastBackup!) > autoBackupEvery)) {
        await backupNow(interactive: false);
      }
    } catch (e) {
      debugPrint('Auto backup skipped: $e');
    }
  }

  /// [quiet] jobs (automatic backups) don't show errors; they retry later.
  Future<T?> _run<T>(Future<T> Function() job, {bool quiet = false}) async {
    busy = true;
    if (!quiet) error = null;
    notifyListeners();
    try {
      return await job();
    } catch (e) {
      if (quiet) {
        debugPrint('Background backup failed: $e');
      } else {
        error = e.toString();
      }
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Signs in. Returns true when a backup already exists on Drive, so the
  /// UI can offer to restore it (e.g. on a new phone or after reinstalling).
  Future<bool> signIn() async {
    final found = await _run(() async {
      final acc = await _drive.signIn();
      email = acc.email;
      return await _drive.lastBackupTime() != null;
    });
    return found ?? false;
  }

  Future<void> signOut() => _run(() async {
        await _drive.signOut();
        email = null;
      });

  /// Silent backup when data changed since the last one (on app pause).
  Future<void> backupIfChanged() async {
    final changed = _students.lastChanged;
    if (!signedIn || busy || changed == null) return;
    if (lastBackup != null && !changed.isAfter(lastBackup!)) return;
    await backupNow(interactive: false);
  }

  Future<bool> backupNow({bool interactive = true}) async {
    final ok = await _run(() async {
      final bytes = await BackupArchive.create(await _repo.baseDir);
      await _drive.upload(bytes, interactive: interactive);
      lastBackup = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastBackup', lastBackup!.toIso8601String());
      return true;
    }, quiet: !interactive);
    return ok ?? false;
  }

  /// Replaces data on this phone with the Drive backup.
  /// Returns false if there was nothing to restore or it failed.
  Future<bool> restore() async {
    final ok = await _run(() async {
      final bytes = await _drive.download();
      if (bytes == null) return false;
      await BackupArchive.restore(await _repo.baseDir, bytes);
      await _students.load();
      return true;
    });
    return ok ?? false;
  }
}
