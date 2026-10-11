import '../models/student.dart';
import '../state/settings_store.dart';
import 'trip_service.dart';

/// One class in the weekly routine.
class RoutineSlot {
  const RoutineSlot({required this.student, required this.slot, required this.inferred});

  final Student student;
  final WeeklySlot slot;

  /// True when guessed from past classes rather than the saved schedule.
  final bool inferred;
}

class PlannedVisit {
  const PlannedVisit({
    required this.routine,
    required this.start,
    required this.travelMinutes,
    required this.travelKm,
    required this.clash,
  });

  final RoutineSlot routine;

  /// Minutes after midnight.
  final int start;
  int get end => start + routine.slot.durationMinutes;
  int get preferredStart => routine.slot.startMinutes;

  /// Travel to this visit from the previous stop (or home).
  final double travelMinutes;
  final double travelKm;

  /// True when there isn't enough time to get here after the previous class.
  final bool clash;
}

class DayPlan {
  const DayPlan({
    required this.weekday,
    required this.visits,
    required this.returnMinutes,
    required this.returnKm,
    required this.usualTravelMinutes,
    required this.liveTraffic,
  });

  final int weekday;
  final List<PlannedVisit> visits;

  /// Travel from the last class back home (0 when no home is set).
  final double returnMinutes;
  final double returnKm;

  /// Travel time when visiting in the usual (time-sorted) order.
  final double usualTravelMinutes;
  final bool liveTraffic;

  double get travelMinutes =>
      visits.fold(0.0, (s, v) => s + v.travelMinutes) + returnMinutes;
  double get travelKm => visits.fold(0.0, (s, v) => s + v.travelKm) + returnKm;
  double get savedMinutes => (usualTravelMinutes - travelMinutes).clamp(0, double.infinity);
  bool get hasClash => visits.any((v) => v.clash);

  double fare(FareRates rates) {
    var total = 0.0;
    for (final v in visits) {
      if (v.travelKm > 0) total += rates.estimate(km: v.travelKm, minutes: v.travelMinutes);
    }
    if (returnKm > 0) total += rates.estimate(km: returnKm, minutes: returnMinutes);
    return total;
  }
}

/// Builds the probable weekly routine and finds the visiting order with the
/// least travel that still respects each student's time (± flex minutes).
class RoutinePlanner {
  RoutinePlanner({TripService? trips}) : _trips = trips ?? TripService();

  final TripService _trips;
  final _matrixCache = <String, TravelMatrix>{};

  /// Brute force is exact and fast up to this many classes in a day.
  static const maxExactVisits = 8;

  /// Saved schedules win; otherwise weekdays taught in at least 2 of the
  /// last 8 weeks, at the usual time.
  static List<RoutineSlot> weeklyRoutine(List<Student> students, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final out = <RoutineSlot>[];
    for (final st in students) {
      if (st.schedule.isNotEmpty) {
        out.addAll(st.schedule.map((s) => RoutineSlot(student: st, slot: s, inferred: false)));
        continue;
      }
      final since = today.subtract(const Duration(days: 56));
      final recent = st.sessions.where((s) => s.isAfter(since)).toList();
      final byDay = <int, List<DateTime>>{};
      for (final s in recent) {
        byDay.putIfAbsent(s.weekday, () => []).add(s);
      }
      byDay.forEach((weekday, list) {
        final weeks = list.map((d) => dateOnly(d).difference(dateOnly(since)).inDays ~/ 7).toSet();
        if (weeks.length < 2) return;
        // "+" is usually pressed at the end of class, so the class most
        // likely started an hour before the typical press time.
        final minutes = list.map((d) => d.hour * 60 + d.minute).toList()..sort();
        final median = minutes[minutes.length ~/ 2];
        final start = ((median - 60).clamp(0, 23 * 60) / 15).round() * 15;
        out.add(RoutineSlot(
          student: st,
          slot: WeeklySlot(weekday: weekday, startMinutes: start),
          inferred: true,
        ));
      });
    }
    return out;
  }

  Future<List<DayPlan>> planWeek(
    List<Student> students, {
    LatLngPoint? home,
    int flexMinutes = 30,
    DateTime? now,
  }) async {
    final routine = weeklyRoutine(students, now: now);
    final plans = <DayPlan>[];
    // Bangladeshi week: Saturday first.
    for (final wd in const [6, 7, 1, 2, 3, 4, 5]) {
      final day = routine.where((r) => r.slot.weekday == wd).toList()
        ..sort((a, b) => a.slot.startMinutes.compareTo(b.slot.startMinutes));
      if (day.isEmpty) continue;
      plans.add(await planDay(wd, day, home: home, flexMinutes: flexMinutes));
    }
    return plans;
  }

  Future<DayPlan> planDay(
    int weekday,
    List<RoutineSlot> day, {
    LatLngPoint? home,
    int flexMinutes = 30,
  }) async {
    // Point 0 is home (if set); then one point per located student.
    final points = <LatLngPoint>[?home];
    final pointOf = <int, int>{};
    for (var i = 0; i < day.length; i++) {
      final st = day[i].student;
      if (st.hasLocation) {
        pointOf[i] = points.length;
        points.add(LatLngPoint(st.latitude!, st.longitude!));
      }
    }
    final cacheKey = points.map((p) => '${p.lat},${p.lng}').join(';');
    final matrix = points.length < 2
        ? const TravelMatrix(minutes: [], km: [], live: false)
        : _matrixCache[cacheKey] ??= await _trips.matrix(points);
    return solveDay(weekday, day,
        matrix: matrix, pointOf: pointOf, hasHome: home != null, flexMinutes: flexMinutes);
  }

  /// Pure part of the planner, separated for testing.
  static DayPlan solveDay(
    int weekday,
    List<RoutineSlot> day, {
    required TravelMatrix matrix,
    required Map<int, int> pointOf,
    required bool hasHome,
    required int flexMinutes,
  }) {
    (double, double) leg(int? fromVisit, int? toVisit) {
      // null visit = home.
      final a = fromVisit == null ? (hasHome ? 0 : null) : pointOf[fromVisit];
      final b = toVisit == null ? (hasHome ? 0 : null) : pointOf[toVisit];
      if (a == null || b == null || a == b) return (0, 0);
      return (matrix.minutes[a][b], matrix.km[a][b]);
    }

    // [early]: start each class as soon as allowed instead of at its usual
    // time, which can make room for a shorter order.
    _Schedule simulate(List<int> order, int flex, {bool early = false}) {
      final visits = <PlannedVisit>[];
      var travel = 0.0;
      var deviation = 0;
      var clashes = 0;
      int? prev;
      int? prevEnd;
      for (final i in order) {
        final r = day[i];
        final (mins, km) = leg(prev, i);
        travel += mins;
        final earliest = r.slot.startMinutes - flex;
        final latest = r.slot.startMinutes + flex;
        final arrive = prevEnd == null ? earliest : prevEnd + mins.ceil();
        // Start as close to the usual time as travel allows (or earliest).
        final target = early ? earliest : r.slot.startMinutes;
        var start = arrive > target ? arrive : target;
        if (start < earliest) start = earliest;
        final clash = start > latest;
        if (clash) clashes++;
        deviation += (start - r.slot.startMinutes).abs();
        visits.add(PlannedVisit(
          routine: r,
          start: start,
          travelMinutes: mins,
          travelKm: km,
          clash: clash,
        ));
        prev = i;
        prevEnd = start + r.slot.durationMinutes;
      }
      final (backMins, backKm) = prev == null ? (0.0, 0.0) : leg(prev, null);
      travel += backMins;
      return _Schedule(visits, travel, deviation, clashes, backMins, backKm);
    }

    final usualOrder = List.generate(day.length, (i) => i);
    final usual = simulate(usualOrder, 0);
    var best = simulate(usualOrder, flexMinutes);

    bool better(_Schedule a, _Schedule b) {
      if (a.clashes != b.clashes) return a.clashes < b.clashes;
      // Travel first; small tie-breaker for staying near usual times.
      return a.travel + a.deviation * 0.05 < b.travel + b.deviation * 0.05 - 0.01;
    }

    if (day.length <= maxExactVisits) {
      for (final order in _permutations(usualOrder)) {
        for (final early in const [false, true]) {
          final s = simulate(order, flexMinutes, early: early);
          if (better(s, best)) best = s;
        }
      }
    }

    return DayPlan(
      weekday: weekday,
      visits: best.visits,
      returnMinutes: best.returnMinutes,
      returnKm: best.returnKm,
      usualTravelMinutes: usual.travel,
      liveTraffic: matrix.live,
    );
  }

  static Iterable<List<int>> _permutations(List<int> items) sync* {
    if (items.length <= 1) {
      yield List.of(items);
      return;
    }
    for (var i = 0; i < items.length; i++) {
      final rest = [...items]..removeAt(i);
      for (final p in _permutations(rest)) {
        yield [items[i], ...p];
      }
    }
  }
}

class _Schedule {
  _Schedule(this.visits, this.travel, this.deviation, this.clashes, this.returnMinutes,
      this.returnKm);

  final List<PlannedVisit> visits;
  final double travel;
  final int deviation;
  final int clashes;
  final double returnMinutes;
  final double returnKm;
}
