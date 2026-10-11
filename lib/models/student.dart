import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String newId() => _uuid.v4();

/// Strips the time part so dates can be compared as calendar days.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Which saved number the call button on the student card dials.
enum ContactKind { student, whatsapp, father, mother }

class Payment {
  Payment({
    String? id,
    required this.date,
    required this.amount,
    this.note = '',
  }) : id = id ?? newId();

  final String id;
  final DateTime date;
  final double amount;
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'amount': amount,
        'note': note,
      };

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'] as String?,
        date: DateTime.parse(j['date'] as String),
        amount: (j['amount'] as num).toDouble(),
        note: j['note'] as String? ?? '',
      );
}

/// A note or homework entry for one day, optionally with photos.
class DayNote {
  DayNote({
    String? id,
    required this.date,
    this.text = '',
    List<String>? imagePaths,
    DateTime? createdAt,
  })  : id = id ?? newId(),
        imagePaths = imagePaths ?? [],
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final DateTime date;
  final String text;

  /// Image file names inside the app's images folder.
  final List<String> imagePaths;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': dayKey(date),
        'text': text,
        'imagePaths': imagePaths,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DayNote.fromJson(Map<String, dynamic> j) => DayNote(
        id: j['id'] as String?,
        date: DateTime.parse(j['date'] as String),
        text: j['text'] as String? ?? '',
        imagePaths: (j['imagePaths'] as List?)?.cast<String>() ?? [],
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
      );
}

/// A weekly time slot when the student is available or usually taught.
/// Used by the routine planner.
class WeeklySlot {
  WeeklySlot({required this.weekday, required this.startMinutes, this.durationMinutes = 60});

  /// DateTime.monday .. DateTime.sunday
  final int weekday;
  final int startMinutes;
  final int durationMinutes;

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'startMinutes': startMinutes,
        'durationMinutes': durationMinutes,
      };

  factory WeeklySlot.fromJson(Map<String, dynamic> j) => WeeklySlot(
        weekday: j['weekday'] as int,
        startMinutes: j['startMinutes'] as int,
        durationMinutes: j['durationMinutes'] as int? ?? 60,
      );
}

class Student {
  Student({
    String? id,
    required this.name,
    this.className = '',
    this.subjects = '',
    this.address = '',
    this.latitude,
    this.longitude,
    this.studentPhone = '',
    this.whatsapp = '',
    this.fatherPhone = '',
    this.motherPhone = '',
    this.defaultContact = ContactKind.father,
    this.monthlyFee,
    this.daysPerCycle,
    this.archived = false,
    DateTime? createdAt,
    List<DateTime>? sessions,
    List<Payment>? payments,
    List<DayNote>? notes,
    List<WeeklySlot>? schedule,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? DateTime.now(),
        sessions = sessions ?? [],
        payments = payments ?? [],
        notes = notes ?? [],
        schedule = schedule ?? [];

  final String id;
  String name;
  String className;
  String subjects;
  String address;
  double? latitude;
  double? longitude;
  String studentPhone;
  String whatsapp;
  String fatherPhone;
  String motherPhone;
  ContactKind defaultContact;

  /// Agreed fee for one payment cycle (usually a month).
  double? monthlyFee;

  /// How many classes make one payment cycle (e.g. 12 or 16), if agreed.
  int? daysPerCycle;
  bool archived;
  final DateTime createdAt;

  /// One entry per class taught (timestamp of when it was recorded).
  final List<DateTime> sessions;
  final List<Payment> payments;
  final List<DayNote> notes;
  final List<WeeklySlot> schedule;

  bool get hasLocation => latitude != null && longitude != null;

  String numberFor(ContactKind kind) => switch (kind) {
        ContactKind.student => studentPhone,
        ContactKind.whatsapp => whatsapp,
        ContactKind.father => fatherPhone,
        ContactKind.mother => motherPhone,
      };

  /// The number the call button uses: the chosen default, or the first saved one.
  String get callNumber {
    final preferred = numberFor(defaultContact);
    if (preferred.trim().isNotEmpty) return preferred;
    for (final k in ContactKind.values) {
      if (numberFor(k).trim().isNotEmpty) return numberFor(k);
    }
    return '';
  }

  DateTime? get lastPaymentDate {
    if (payments.isEmpty) return null;
    return payments.map((p) => p.date).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Classes taught after the most recent payment.
  int get sessionsSinceLastPayment {
    final last = lastPaymentDate;
    if (last == null) return sessions.length;
    return sessions.where((s) => s.isAfter(last)).length;
  }

  int get totalSessions => sessions.length;

  double get totalReceived => payments.fold(0.0, (sum, p) => sum + p.amount);

  int sessionsOn(DateTime day) {
    final d = dateOnly(day);
    return sessions.where((s) => dateOnly(s) == d).length;
  }

  int sessionsInMonth(int year, int month) =>
      sessions.where((s) => s.year == year && s.month == month).length;

  List<DayNote> notesOn(DateTime day) {
    final d = dateOnly(day);
    return notes.where((n) => dateOnly(n.date) == d).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// The most recent day before [day] that has notes, for "previous homework".
  DateTime? previousNoteDay(DateTime day) {
    final d = dateOnly(day);
    DateTime? best;
    for (final n in notes) {
      final nd = dateOnly(n.date);
      if (nd.isBefore(d) && (best == null || nd.isAfter(best))) best = nd;
    }
    return best;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'className': className,
        'subjects': subjects,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'studentPhone': studentPhone,
        'whatsapp': whatsapp,
        'fatherPhone': fatherPhone,
        'motherPhone': motherPhone,
        'defaultContact': defaultContact.name,
        'monthlyFee': monthlyFee,
        'daysPerCycle': daysPerCycle,
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
        'sessions': sessions.map((s) => s.toIso8601String()).toList(),
        'payments': payments.map((p) => p.toJson()).toList(),
        'notes': notes.map((n) => n.toJson()).toList(),
        'schedule': schedule.map((s) => s.toJson()).toList(),
      };

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: j['id'] as String?,
        name: j['name'] as String? ?? '',
        className: j['className'] as String? ?? '',
        subjects: j['subjects'] as String? ?? '',
        address: j['address'] as String? ?? '',
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        studentPhone: j['studentPhone'] as String? ?? '',
        whatsapp: j['whatsapp'] as String? ?? '',
        fatherPhone: j['fatherPhone'] as String? ?? '',
        motherPhone: j['motherPhone'] as String? ?? '',
        defaultContact: ContactKind.values.firstWhere(
          (k) => k.name == j['defaultContact'],
          orElse: () => ContactKind.father,
        ),
        monthlyFee: (j['monthlyFee'] as num?)?.toDouble(),
        daysPerCycle: j['daysPerCycle'] as int?,
        archived: j['archived'] as bool? ?? false,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
        sessions: (j['sessions'] as List? ?? [])
            .map((s) => DateTime.parse(s as String))
            .toList(),
        payments: (j['payments'] as List? ?? [])
            .map((p) => Payment.fromJson(p as Map<String, dynamic>))
            .toList(),
        notes: (j['notes'] as List? ?? [])
            .map((n) => DayNote.fromJson(n as Map<String, dynamic>))
            .toList(),
        schedule: (j['schedule'] as List? ?? [])
            .map((s) => WeeklySlot.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}
