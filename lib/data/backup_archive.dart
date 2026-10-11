import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Packs `students.json` and the `images/` folder into one zip, and back.
class BackupArchive {
  static const dataFile = 'students.json';
  static const imagesFolder = 'images';

  static Future<Uint8List> create(Directory baseDir) async {
    final archive = Archive();
    final data = File('${baseDir.path}/$dataFile');
    if (await data.exists()) {
      archive.addFile(ArchiveFile.bytes(dataFile, await data.readAsBytes()));
    }
    final images = Directory('${baseDir.path}/$imagesFolder');
    if (await images.exists()) {
      await for (final f in images.list()) {
        if (f is File) {
          final name = f.uri.pathSegments.last;
          archive.addFile(ArchiveFile.bytes('$imagesFolder/$name', await f.readAsBytes()));
        }
      }
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Replaces local data with the backup. Throws [FormatException] when the
  /// zip has no data file, leaving local data untouched.
  static Future<void> restore(Directory baseDir, List<int> zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final data = archive.findFile(dataFile);
    if (data == null) throw const FormatException('Backup has no students.json');

    final images = Directory('${baseDir.path}/$imagesFolder');
    if (await images.exists()) await images.delete(recursive: true);
    await images.create(recursive: true);
    for (final f in archive.files) {
      if (!f.isFile || !f.name.startsWith('$imagesFolder/')) continue;
      final name = f.name.substring(imagesFolder.length + 1);
      // Reject anything that tries to escape the images folder.
      if (name.isEmpty || name.contains('/') || name.contains('\\') || name.contains('..')) continue;
      await File('${images.path}/$name').writeAsBytes(f.readBytes()!);
    }
    final tmp = File('${baseDir.path}/$dataFile.tmp');
    await tmp.writeAsBytes(data.readBytes()!);
    await tmp.rename('${baseDir.path}/$dataFile');
  }
}
