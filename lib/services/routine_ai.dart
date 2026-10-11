import '../models/student.dart';
import 'ai_service.dart';
import 'routine_planner.dart';

/// Builds the AI request from the computed week. Only first names, class,
/// area and times are sent — no phone numbers or full addresses.
class RoutineAi {
  static const _days = {
    1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday',
    5: 'Friday', 6: 'Saturday', 7: 'Sunday',
  };

  static String _firstName(Student s) => s.name.trim().split(RegExp(r'\s+')).first;

  static String _area(Student s) {
    final parts = s.address.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'unknown area';
    return parts.length <= 2 ? parts.join(', ') : parts.sublist(parts.length - 2).join(', ');
  }

  static String _time(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  static List<AiMessage> buildMessages({
    required List<DayPlan> week,
    required List<Student> students,
    required bool bangla,
    required int flexMinutes,
  }) {
    final b = StringBuffer()
      ..writeln('My tuition week (computed by the app, travel by motorbike):');
    for (final day in week) {
      b.writeln('${_days[day.weekday]}:');
      for (final v in day.visits) {
        final st = v.routine.student;
        b.writeln('- ${_time(v.start)}-${_time(v.end)} ${_firstName(st)}'
            '${st.className.isEmpty ? '' : ' (class ${st.className})'}'
            '${st.batch.isEmpty ? '' : ' [batch ${st.batch}]'}'
            ', ${_area(st)}, ${v.travelMinutes.round()} min travel before'
            '${v.start != v.preferredStart ? ', usually ${_time(v.preferredStart)}' : ''}'
            '${v.clash ? ', CLASH: not enough travel time' : ''}');
      }
      b.writeln('  total travel ${day.travelMinutes.round()} min, ${day.travelKm.toStringAsFixed(1)} km');
    }
    final unscheduled = students
        .where((s) => !week.any((d) => d.visits.any((v) => v.routine.student.id == s.id)))
        .map(_firstName)
        .toList();
    if (unscheduled.isNotEmpty) {
      b.writeln('Students with no fixed days yet: ${unscheduled.join(', ')}');
    }
    final due = students
        .where((s) => s.daysPerCycle != null && s.sessionsSinceLastPayment >= s.daysPerCycle!)
        .map(_firstName)
        .toList();
    if (due.isNotEmpty) b.writeln('Payment due (finished their monthly classes): ${due.join(', ')}');
    b
      ..writeln('Classes may move by up to $flexMinutes minutes.')
      ..writeln()
      ..writeln('Please give me:')
      ..writeln('1. My weekly routine, day by day, in a clean list.')
      ..writeln('2. Up to 5 practical tips to cut travel time and cost, fix clashes and balance busy days.')
      ..writeln('3. Free time windows where I could take a new tuition.')
      ..writeln('Keep it under 250 words.');

    return [
      AiMessage(
        'system',
        'You are a friendly planning assistant for a private tutor in Bangladesh '
            '(week starts Saturday; Friday is the weekend). '
            '${bangla ? 'Reply only in Bangla (বাংলা), using Bangla digits.' : 'Reply in simple English.'} '
            'Use short bullet points. Do not use tables or markdown headings.',
      ),
      AiMessage('user', b.toString()),
    ];
  }
}
