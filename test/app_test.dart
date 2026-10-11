import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuition_tracker/data/student_repository.dart';
import 'package:tuition_tracker/main.dart';
import 'package:tuition_tracker/models/student.dart';
import 'package:tuition_tracker/state/settings_store.dart';
import 'package:tuition_tracker/state/student_store.dart';

void main() {
  late Directory dir;
  late SettingsStore settings;
  late StudentStore students;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting();
    dir = Directory.systemTemp.createTempSync('tt_app');
    settings = SettingsStore();
    students = StudentStore(StudentRepository(baseDir: dir));
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
}
