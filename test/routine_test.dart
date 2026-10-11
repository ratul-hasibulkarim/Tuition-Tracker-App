import 'package:flutter_test/flutter_test.dart';
import 'package:tuition_tracker/models/student.dart';
import 'package:tuition_tracker/services/routine_planner.dart';
import 'package:tuition_tracker/services/trip_service.dart';

/// Travel matrix where moving between points costs |i - j| * 10 minutes/km,
/// except the pairs in [overrides].
TravelMatrix lineMatrix(int n, {Map<(int, int), double> overrides = const {}}) {
  final m = List.generate(n, (i) => List.generate(n, (j) => overrides[(i, j)] ?? (i - j).abs() * 10.0));
  return TravelMatrix(minutes: m, km: m.map((r) => r.map((v) => v / 10).toList()).toList(), live: false);
}

RoutineSlot slot(String name, int weekday, int hour, {int minute = 0}) => RoutineSlot(
      student: Student(name: name, latitude: 23.7, longitude: 90.4),
      slot: WeeklySlot(weekday: weekday, startMinutes: hour * 60 + minute),
      inferred: false,
    );

void main() {
  test('saved schedule is used as the weekly routine', () {
    final st = Student(name: 'A', schedule: [
      WeeklySlot(weekday: DateTime.saturday, startMinutes: 16 * 60),
      WeeklySlot(weekday: DateTime.monday, startMinutes: 16 * 60),
    ]);
    final r = RoutinePlanner.weeklyRoutine([st]);
    expect(r.map((x) => x.slot.weekday), [DateTime.saturday, DateTime.monday]);
    expect(r.every((x) => !x.inferred), isTrue);
  });

  test('routine is inferred from recent classes when no schedule', () {
    final now = DateTime(2026, 10, 10); // Saturday
    // Taught on Sundays at ~17:00 (button pressed) for 3 weeks, one random Tuesday.
    final st = Student(name: 'B', sessions: [
      DateTime(2026, 9, 20, 17, 0),
      DateTime(2026, 9, 27, 17, 10),
      DateTime(2026, 10, 4, 16, 55),
      DateTime(2026, 9, 29, 18, 0),
    ]);
    final r = RoutinePlanner.weeklyRoutine([st], now: now);
    expect(r, hasLength(1));
    expect(r.single.slot.weekday, DateTime.sunday);
    expect(r.single.slot.startMinutes, 16 * 60); // an hour before the usual press
    expect(r.single.inferred, isTrue);
  });

  test('reorders flexible classes to cut travel', () {
    // A=0, B=1, C=2 on a line. Usual order A(16:00) C(17:30) B(18:00)
    // zig-zags (20+10 min); with ±60 min flex, A→B→C is 10+10 min.
    final day = [slot('A', 6, 16), slot('C', 6, 17, minute: 30), slot('B', 6, 18)];
    final plan = RoutinePlanner.solveDay(6, day,
        matrix: lineMatrix(3), pointOf: {0: 0, 1: 2, 2: 1}, hasHome: false, flexMinutes: 60);
    expect(plan.visits.map((v) => v.routine.student.name), ['A', 'B', 'C']);
    expect(plan.hasClash, isFalse);
    expect(plan.travelMinutes, lessThan(plan.usualTravelMinutes));
    expect(plan.savedMinutes, greaterThan(0));
  });

  test('keeps usual order when times are fixed', () {
    final day = [slot('A', 6, 16), slot('C', 6, 17, minute: 30), slot('B', 6, 18, minute: 45)];
    final plan = RoutinePlanner.solveDay(6, day,
        matrix: lineMatrix(3), pointOf: {0: 0, 1: 2, 2: 1}, hasHome: false, flexMinutes: 0);
    expect(plan.visits.map((v) => v.routine.student.name), ['A', 'C', 'B']);
  });

  test('flags a clash when travel time does not fit', () {
    // A 16:00-17:00, B at 17:00 but 45 min away and no flex.
    final day = [slot('A', 6, 16), slot('B', 6, 17)];
    final plan = RoutinePlanner.solveDay(6, day,
        matrix: lineMatrix(2, overrides: {(0, 1): 45, (1, 0): 45}),
        pointOf: {0: 0, 1: 1},
        hasHome: false,
        flexMinutes: 0);
    expect(plan.hasClash, isTrue);
    expect(plan.visits.last.clash, isTrue);
    expect(plan.visits.last.start, 17 * 60 + 45);
  });

  test('students without a location still appear with no travel', () {
    final noLoc = RoutineSlot(
      student: Student(name: 'X'),
      slot: WeeklySlot(weekday: 6, startMinutes: 15 * 60),
      inferred: false,
    );
    final plan = RoutinePlanner.solveDay(6, [noLoc, slot('A', 6, 17)],
        matrix: lineMatrix(2), pointOf: {1: 1}, hasHome: true, flexMinutes: 30);
    expect(plan.visits, hasLength(2));
    expect(plan.visits.firstWhere((v) => v.routine.student.name == 'X').travelMinutes, 0);
  });
}
