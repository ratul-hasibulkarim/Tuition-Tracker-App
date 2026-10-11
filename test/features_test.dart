import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tuition_tracker/data/backup_archive.dart';
import 'package:tuition_tracker/data/student_repository.dart';
import 'package:tuition_tracker/l10n/strings.dart';
import 'package:tuition_tracker/models/student.dart';
import 'package:tuition_tracker/screens/income_screen.dart';
import 'package:tuition_tracker/services/ai_service.dart';
import 'package:tuition_tracker/services/api_client.dart';
import 'package:tuition_tracker/services/routine_ai.dart';
import 'package:tuition_tracker/services/routine_planner.dart';
import 'package:tuition_tracker/services/trip_service.dart';
import 'package:tuition_tracker/state/student_store.dart';

void main() {
  group('Bangla digits', () {
    test('converts digits only in Bangla', () {
      expect(const S(true).n(2026), '২০২৬');
      expect(const S(false).n(2026), '2026');
      expect(const S(true).n('12/16'), '১২/১৬');
      expect(const S(true).n(2.5), '২.৫');
    });

    test('money uses separators and Taka sign', () {
      expect(const S(false).money(12500), '৳12,500');
      expect(const S(true).money(12500), '৳১২,৫০০');
      expect(const S(false).money(999), '৳999');
      expect(const S(false).money(1000000), '৳1,000,000');
    });

    test('Bangla strings with counts use Bangla digits', () {
      expect(const S(true).daysSincePayment(12), 'পেমেন্টের পর ১২ দিন');
    });
  });

  group('Backup archive', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('tt_backup'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('round trip restores data and images', () async {
      final repo = StudentRepository(baseDir: dir);
      await repo.save([Student(name: 'Rahim')]);
      final images = await repo.imagesDir();
      File('${images.path}/a.jpg').writeAsBytesSync([1, 2, 3]);
      final zip = await BackupArchive.create(dir);

      // Wipe and change local data, then restore.
      await repo.save([Student(name: 'Other')]);
      File('${images.path}/a.jpg').deleteSync();
      File('${images.path}/stale.jpg').writeAsBytesSync([9]);
      await BackupArchive.restore(dir, zip);

      expect((await repo.load()).single.name, 'Rahim');
      expect(File('${images.path}/a.jpg').readAsBytesSync(), [1, 2, 3]);
      expect(File('${images.path}/stale.jpg').existsSync(), isFalse);
    });

    test('rejects zips without data and ignores unsafe paths', () async {
      final bad = ZipEncoder().encode(Archive()..addFile(ArchiveFile.bytes('x.txt', [1])));
      expect(() => BackupArchive.restore(dir, bad), throwsFormatException);

      final sneaky = ZipEncoder().encode(Archive()
        ..addFile(ArchiveFile.bytes('students.json', utf8.encode('{"students":[]}')))
        ..addFile(ArchiveFile.bytes('images/../../evil.txt', [1])));
      await BackupArchive.restore(dir, sneaky);
      expect(File('${dir.parent.path}/evil.txt').existsSync(), isFalse);
    });
  });

  group('Store editing and batches', () {
    late Directory dir;
    late StudentStore store;
    setUp(() async {
      dir = Directory.systemTemp.createTempSync('tt_store');
      store = StudentStore(StudentRepository(baseDir: dir));
      await store.load();
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('updatePayment edits in place', () async {
      final st = Student(name: 'A');
      await store.upsert(st);
      final p = Payment(date: DateTime(2026, 9, 1), amount: 3000);
      await store.addPayment(st, p);
      await store.updatePayment(st, Payment(id: p.id, date: p.date, amount: 3500, note: 'fixed'));
      expect(st.payments.single.amount, 3500);
      expect(st.payments.single.note, 'fixed');
    });

    test('updateNote keeps, removes and adds photos', () async {
      final repo = StudentRepository(baseDir: dir);
      final st = Student(name: 'A');
      await store.upsert(st);
      final src = File('${dir.path}/pick.jpg')..writeAsBytesSync([1]);
      await store.addNote(st, DateTime(2026, 9, 1), 'HW 1', [src.path, src.path]);
      final note = st.notes.single;
      final [keep, drop] = note.imagePaths;
      await store.updateNote(st, note, 'HW 1 (edited)', [keep], [src.path]);
      final edited = st.notes.single;
      expect(edited.id, note.id);
      expect(edited.text, 'HW 1 (edited)');
      expect(edited.imagePaths, hasLength(2));
      expect(edited.imagePaths.first, keep);
      final images = await repo.imagesDir();
      expect(File('${images.path}/$drop').existsSync(), isFalse);
    });

    test('batches group students and share class/payment actions', () async {
      await store.addMany([
        Student(name: 'A', batch: 'HSC 26'),
        Student(name: 'B', batch: 'HSC 26'),
        Student(name: 'C', batch: 'SSC 27'),
        Student(name: 'D'),
      ]);
      expect(store.batches, ['HSC 26', 'SSC 27']);
      final hsc = store.inBatch('HSC 26');
      expect(hsc.map((s) => s.name), ['A', 'B']);

      final t = await store.addSessionForAll(hsc);
      expect(hsc.every((s) => s.sessionsSinceLastPayment == 1), isTrue);
      await store.removeSessionForAll(hsc, t);
      expect(hsc.every((s) => s.totalSessions == 0), isTrue);

      await store.addPayments({hsc.first: Payment(date: DateTime.now(), amount: 2000)});
      expect(hsc.first.totalReceived, 2000);
      expect(hsc.last.totalReceived, 0);
    });
  });

  test('income month sums payments and classes', () {
    final a = Student(name: 'A', sessions: [DateTime(2026, 9, 2), DateTime(2026, 9, 9)], payments: [
      Payment(date: DateTime(2026, 9, 5), amount: 3000),
      Payment(date: DateTime(2026, 8, 5), amount: 3000),
    ]);
    final b = Student(name: 'B', payments: [Payment(date: DateTime(2026, 9, 20), amount: 1500)]);
    final m = IncomeMonth(2026, 9, [a, b, Student(name: 'C')]);
    expect(m.total, 4500);
    expect(m.classes, 2);
    expect(m.byStudent.keys.map((s) => s.name), ['A', 'B']);
  });

  group('AI', () {
    test('own key calls the provider directly', () async {
      late http.Request sent;
      final ai = AiService(
        api: ApiClient(baseUrl: ''),
        provider: AiProvider.openRouter,
        ownKey: 'k',
        client: MockClient((r) async {
          sent = r;
          return http.Response(
            jsonEncode({'choices': [{'message': {'content': 'রুটিন'}}]}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      expect(await ai.chat([const AiMessage('user', 'hi')]), 'রুটিন');
      expect(sent.url.toString(), 'https://openrouter.ai/api/v1/chat/completions');
      expect(sent.headers['Authorization'], 'Bearer k');
      expect(jsonDecode(sent.body)['model'], 'deepseek/deepseek-chat-v3.1:free');
    });

    test('falls back to the server and errors when nothing is set up', () async {
      final server = ApiClient(
        baseUrl: 'https://api.example.com/',
        token: 't',
        client: MockClient((r) async {
          expect(r.url.toString(), 'https://api.example.com/v1/ai/chat');
          expect(r.headers['X-App-Token'], 't');
          return http.Response(jsonEncode({'text': 'plan'}), 200);
        }),
      );
      expect(await AiService(api: server).chat([const AiMessage('user', 'x')]), 'plan');
      expect(() => AiService(api: ApiClient(baseUrl: '')).chat([]), throwsA(isA<AiNotConfigured>()));
    });

    test('routine prompt has no phone numbers and asks for Bangla', () {
      final st = Student(
        name: 'Rahim Uddin',
        address: 'House 5, Road 2, Dhanmondi, Dhaka',
        fatherPhone: '01711223344',
        className: '8',
      );
      final plan = RoutinePlanner.solveDay(
        6,
        [RoutineSlot(student: st, slot: WeeklySlot(weekday: 6, startMinutes: 960), inferred: false)],
        matrix: const TravelMatrix(minutes: [], km: [], live: false),
        pointOf: const {},
        hasHome: false,
        flexMinutes: 30,
      );
      final msgs = RoutineAi.buildMessages(week: [plan], students: [st], bangla: true, flexMinutes: 30);
      final all = msgs.map((m) => m.content).join('\n');
      expect(all, contains('Rahim'));
      expect(all, isNot(contains('Uddin')));
      expect(all, isNot(contains('01711223344')));
      expect(all, isNot(contains('House 5')));
      expect(all, contains('Dhanmondi, Dhaka'));
      expect(all, contains('16:00-17:00'));
      expect(msgs.first.content, contains('Bangla'));
    });
  });

  test('trip service uses the server route when configured', () async {
    final trips = TripService(
      api: ApiClient(
        baseUrl: 'https://api.example.com',
        client: MockClient((r) async => http.Response(jsonEncode({'km': 4.2, 'minutes': 18}), 200)),
      ),
    );
    final t = await trips.estimate(const LatLngPoint(23.7, 90.3), const LatLngPoint(23.8, 90.4));
    expect(t.live, isTrue);
    expect(t.km, 4.2);
  });

  test('trip service falls back to rough estimate on server error', () async {
    final trips = TripService(
      api: ApiClient(
        baseUrl: 'https://api.example.com',
        client: MockClient((r) async => http.Response('{"error":"x"}', 502)),
      ),
    );
    final t = await trips.estimate(const LatLngPoint(23.7, 90.3), const LatLngPoint(23.8, 90.4));
    expect(t.live, isFalse);
  });
}
