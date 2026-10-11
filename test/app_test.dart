import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuition_tracker/data/student_repository.dart';
import 'package:tuition_tracker/main.dart';
import 'package:tuition_tracker/models/student.dart';
import 'package:tuition_tracker/state/backup_store.dart';
import 'package:tuition_tracker/state/settings_store.dart';
import 'package:tuition_tracker/state/student_store.dart';

void main() {
  late Directory dir;
  late SettingsStore settings;
  late StudentStore students;
  late BackupStore backup;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await initializeDateFormatting();
    dir = Directory.systemTemp.createTempSync('tt_app');
    settings = SettingsStore();
    final repo = StudentRepository(baseDir: dir);
    students = StudentStore(repo);
    backup = BackupStore(repo, students);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.runAsync(() async {
      await settings.load();
      await students.load();
    });
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: students),
        ChangeNotifierProvider.value(value: backup),
      ],
      child: const TuitionTrackerApp(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('empty state shows Add tuition button', (tester) async {
    await pumpApp(tester);
    expect(find.text('No tuitions yet'), findsOneWidget);
    expect(find.text('Add tuition'), findsOneWidget);
  });

  testWidgets('plus button adds a class to the student card', (tester) async {
    await tester.runAsync(() => students.upsert(Student(name: 'Rahim', address: 'Mirpur 10')));
    await pumpApp(tester);
    expect(find.text('Rahim'), findsOneWidget);
    expect(find.text('Mirpur 10'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Add a class taught'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(students.current.single.sessionsSinceLastPayment, 1);
    expect(find.text('Class added for Rahim'), findsOneWidget);
  });

  testWidgets('switching to Bangla translates the UI', (tester) async {
    await pumpApp(tester);
    await tester.runAsync(() => settings.setLocale(const Locale('bn')));
    await tester.pumpAndSettle();
    expect(find.text('টিউশন যোগ করুন'), findsOneWidget);
  });

  testWidgets('add tuition form saves a student', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Add tuition'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Student name'), 'Nila');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(students.current.single.name, 'Nila');
    expect(find.text('Nila'), findsOneWidget);
  });

  testWidgets('detail screen shows calendar and records a payment', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final st = Student(name: 'Tania', monthlyFee: 4000, daysPerCycle: 12, sessions: [
      DateTime.now().subtract(const Duration(days: 2)),
      DateTime.now().subtract(const Duration(days: 1)),
    ]);
    await tester.runAsync(() => students.upsert(st));
    await pumpApp(tester);
    await tester.tap(find.text('Tania'));
    await tester.pumpAndSettle();
    expect(find.text('Classes calendar'), findsOneWidget);
    expect(find.text('2 days since payment'), findsOneWidget);

    await tester.ensureVisible(find.text('Record payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();
    expect(find.text('4000'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    // load() re-reads from disk, so check the store's copy.
    final saved = students.current.single;
    expect(saved.totalReceived, 4000);
    expect(saved.sessionsSinceLastPayment, 0);
    expect(find.text('0 days since payment'), findsOneWidget);
  });

  testWidgets('Bangla mode shows Bangla digits on the card', (tester) async {
    await tester.runAsync(() => students.upsert(Student(
        name: 'Rahim', daysPerCycle: 12, sessions: List.generate(3, (i) => DateTime(2026, 9, i + 1)))));
    await pumpApp(tester);
    expect(find.text('3/12'), findsOneWidget);
    await tester.runAsync(() => settings.setLocale(const Locale('bn')));
    await tester.pumpAndSettle();
    expect(find.text('৩/১২'), findsOneWidget);
  });

  testWidgets('batch chip filters and adds a class for the whole batch', (tester) async {
    await tester.runAsync(() => students.addMany([
          Student(name: 'Asif', batch: 'HSC 26'),
          Student(name: 'Bina', batch: 'HSC 26'),
          Student(name: 'Chad'),
        ]));
    await pumpApp(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'HSC 26'));
    await tester.pumpAndSettle();
    expect(find.text('Chad'), findsNothing);
    expect(find.text('2 students'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Add class for all'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(students.inBatch('HSC 26').every((s) => s.totalSessions == 1), isTrue);
    expect(students.current.firstWhere((s) => s.name == 'Chad').totalSessions, 0);
  });

  testWidgets('income summary opens from the menu', (tester) async {
    final st = Student(name: 'Tania', monthlyFee: 4000);
    st.payments.add(Payment(date: DateTime.now(), amount: 4000));
    await tester.runAsync(() => students.upsert(st));
    await pumpApp(tester);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Income summary'));
    await tester.pumpAndSettle();
    expect(find.text('Received this month'), findsOneWidget);
    expect(find.text('৳4,000'), findsWidgets);
  });

  testWidgets('routine tab plans students with a schedule', (tester) async {
    await tester.runAsync(() => students.addMany([
          Student(name: 'Asif', latitude: 23.75, longitude: 90.37,
              schedule: [WeeklySlot(weekday: DateTime.saturday, startMinutes: 16 * 60)]),
          Student(name: 'Bina', latitude: 23.78, longitude: 90.41,
              schedule: [WeeklySlot(weekday: DateTime.saturday, startMinutes: 18 * 60)]),
        ]));
    await pumpApp(tester);
    await tester.tap(find.text('Routine'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('2 classes'), findsOneWidget);
    expect(find.text('Asif'), findsWidgets);
    expect(find.text('Bina'), findsWidgets);
    expect(find.text('Travel times are rough estimates'), findsOneWidget);
  });
}
