import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuition_tracker/data/student_repository.dart';
import 'package:tuition_tracker/models/student.dart';
import 'package:tuition_tracker/services/launcher.dart';
import 'package:tuition_tracker/services/trip_service.dart';
import 'package:tuition_tracker/state/settings_store.dart';

void main() {
  group('Student metrics', () {
    test('counts classes since the last payment', () {
      final st = Student(name: 'Rahim', sessions: [
        DateTime(2026, 9, 1, 16),
        DateTime(2026, 9, 3, 16),
        DateTime(2026, 9, 5, 16),
      ]);
      expect(st.sessionsSinceLastPayment, 3);

      st.payments.add(Payment(date: DateTime(2026, 9, 4), amount: 3000));
      expect(st.sessionsSinceLastPayment, 1);
      expect(st.totalSessions, 3);
      expect(st.totalReceived, 3000);

      st.payments.add(Payment(date: DateTime(2026, 9, 6), amount: 1500));
      expect(st.sessionsSinceLastPayment, 0);
      expect(st.totalReceived, 4500);
      expect(st.lastPaymentDate, DateTime(2026, 9, 6));
    });

    test('call number falls back when default is empty', () {
      final st = Student(name: 'Karim', motherPhone: '01711000000');
      expect(st.defaultContact, ContactKind.father);
      expect(st.callNumber, '01711000000');
      st.fatherPhone = '01811000000';
      expect(st.callNumber, '01811000000');
    });

    test('finds notes per day and the previous homework day', () {
      final st = Student(name: 'Nila', notes: [
        DayNote(date: DateTime(2026, 9, 1), text: 'Ch 1'),
        DayNote(date: DateTime(2026, 9, 4), text: 'Ch 2'),
      ]);
      expect(st.notesOn(DateTime(2026, 9, 4, 18)).single.text, 'Ch 2');
      expect(st.previousNoteDay(DateTime(2026, 9, 4)), DateTime(2026, 9, 1));
      expect(st.previousNoteDay(DateTime(2026, 9, 1)), isNull);
    });

    test('JSON round trip keeps all data', () {
      final st = Student(
        name: 'Tania',
        address: 'Dhanmondi 27',
        latitude: 23.75,
        longitude: 90.37,
        whatsapp: '01900000000',
        defaultContact: ContactKind.mother,
        monthlyFee: 4000,
        daysPerCycle: 12,
        sessions: [DateTime(2026, 9, 1, 16)],
        payments: [Payment(date: DateTime(2026, 9, 2), amount: 4000, note: 'Aug')],
        notes: [DayNote(date: DateTime(2026, 9, 1), text: 'HW', imagePaths: ['a.jpg'])],
        schedule: [WeeklySlot(weekday: DateTime.saturday, startMinutes: 960)],
      );
      final back = Student.fromJson(st.toJson());
      expect(back.toJson(), st.toJson());
    });
  });

  test('repository saves and loads students', () async {
    final dir = await Directory.systemTemp.createTemp('tt_test');
    addTearDown(() => dir.delete(recursive: true));
    final repo = StudentRepository(baseDir: dir);
    expect(await repo.load(), isEmpty);
    await repo.save([Student(name: 'A'), Student(name: 'B')]);
    final loaded = await repo.load();
    expect(loaded.map((s) => s.name), ['A', 'B']);
  });

  test('Bangladeshi numbers are converted for WhatsApp', () {
    expect(Launcher.toInternational('01711-223344'), '8801711223344');
    expect(Launcher.toInternational('+8801711223344'), '8801711223344');
    expect(Launcher.toInternational('008801711223344'), '8801711223344');
  });

  test('fare estimate respects the minimum fare', () {
    const f = FareRates(base: 30, perKm: 15, perMinute: 1, minimum: 45);
    expect(f.estimate(km: 0.2, minutes: 1), 45);
    expect(f.estimate(km: 5, minutes: 20), 30 + 75 + 20);
  });

  test('rough trip estimate is sensible for Dhaka distances', () {
    // Dhanmondi 27 to Gulshan 1 is roughly 6-7 km straight line.
    final t = TripService.roughEstimate(
        const LatLngPoint(23.7561, 90.3720), const LatLngPoint(23.7806, 90.4166));
    expect(t.km, inInclusiveRange(6, 10));
    expect(t.live, isFalse);
  });
}
