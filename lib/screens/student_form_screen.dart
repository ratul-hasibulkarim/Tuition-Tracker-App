import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/student.dart';
import '../state/student_store.dart';
import 'location_picker_screen.dart';

/// Add a new tuition, or edit an existing one when [student] is given.
class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({super.key, this.student});

  final Student? student;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Student? _existing = widget.student;

  late final _name = TextEditingController(text: _existing?.name);
  late final _className = TextEditingController(text: _existing?.className);
  late final _subjects = TextEditingController(text: _existing?.subjects);
  late final _address = TextEditingController(text: _existing?.address);
  late final _studentPhone = TextEditingController(text: _existing?.studentPhone);
  late final _whatsapp = TextEditingController(text: _existing?.whatsapp);
  late final _father = TextEditingController(text: _existing?.fatherPhone);
  late final _mother = TextEditingController(text: _existing?.motherPhone);
  late final _fee = TextEditingController(text: _fmt(_existing?.monthlyFee));
  late final _cycle = TextEditingController(text: _existing?.daysPerCycle?.toString());

  late double? _lat = _existing?.latitude;
  late double? _lng = _existing?.longitude;
  late ContactKind _defaultContact = _existing?.defaultContact ?? ContactKind.father;
  late final List<WeeklySlot> _schedule = [...?_existing?.schedule];

  static String? _fmt(double? v) =>
      v == null ? null : (v == v.roundToDouble() ? v.round().toString() : v.toString());

  @override
  void dispose() {
    for (final c in [
      _name, _className, _subjects, _address, _studentPhone,
      _whatsapp, _father, _mother, _fee, _cycle,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initial: _lat != null && _lng != null ? LatLng(_lat!, _lng!) : null,
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _lat = picked.latLng.latitude;
      _lng = picked.latLng.longitude;
      if (_address.text.trim().isEmpty && picked.address.isNotEmpty) {
        _address.text = picked.address;
      }
    });
  }

  Future<void> _addSlot() async {
    final s = S.of(context);
    var weekday = DateTime.saturday;
    final day = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(s.addSlot),
        children: [
          for (final wd in [6, 7, 1, 2, 3, 4, 5])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, wd),
              child: Text(s.weekday(wd)),
            ),
        ],
      ),
    );
    if (day == null || !mounted) return;
    weekday = day;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 16, minute: 0),
    );
    if (time == null) return;
    setState(() {
      _schedule.add(WeeklySlot(weekday: weekday, startMinutes: time.hour * 60 + time.minute));
      _schedule.sort((a, b) => a.weekday != b.weekday
          ? a.weekday.compareTo(b.weekday)
          : a.startMinutes.compareTo(b.startMinutes));
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final store = context.read<StudentStore>();
    final st = _existing ?? Student(name: '');
    st
      ..name = _name.text.trim()
      ..className = _className.text.trim()
      ..subjects = _subjects.text.trim()
      ..address = _address.text.trim()
      ..latitude = _lat
      ..longitude = _lng
      ..studentPhone = _studentPhone.text.trim()
      ..whatsapp = _whatsapp.text.trim()
      ..fatherPhone = _father.text.trim()
      ..motherPhone = _mother.text.trim()
      ..defaultContact = _defaultContact
      ..monthlyFee = double.tryParse(_fee.text.trim())
      ..daysPerCycle = int.tryParse(_cycle.text.trim());
    st.schedule
      ..clear()
      ..addAll(_schedule);
    await store.upsert(st);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    String? numberValidator(String? v) {
      final t = v?.trim() ?? '';
      if (t.isEmpty) return null;
      return double.tryParse(t) == null ? s.invalidNumber : null;
    }

    Widget section(String title) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(title,
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );

    Widget phone(TextEditingController c, String label, IconData icon) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: c,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? s.addTuition : s.editTuition),
        actions: [
          TextButton(onPressed: _save, child: Text(s.save)),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextFormField(
              controller: _name,
              autofocus: _existing == null,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: s.studentName,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (v) => (v?.trim().isEmpty ?? true) ? s.nameRequired : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _className,
                    decoration: InputDecoration(labelText: s.classLabel, helperText: s.optional),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _subjects,
                    decoration:
                        InputDecoration(labelText: s.subjectsLabel, helperText: s.optional),
                  ),
                ),
              ],
            ),
            section(s.address),
            TextFormField(
              controller: _address,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: s.address,
                prefixIcon: const Icon(Icons.home_outlined),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: Icon(_lat != null ? Icons.check_circle : Icons.map_outlined),
              label: Text(_lat != null ? s.locationPicked : s.pickOnMap),
            ),
            section(s.contacts),
            phone(_studentPhone, s.studentPhone, Icons.phone_android),
            phone(_whatsapp, s.whatsapp, Icons.chat_outlined),
            phone(_father, s.fatherPhone, Icons.man_outlined),
            phone(_mother, s.motherPhone, Icons.woman_outlined),
            DropdownButtonFormField<ContactKind>(
              initialValue: _defaultContact,
              decoration: InputDecoration(
                labelText: s.defaultCallNumber,
                prefixIcon: const Icon(Icons.call_outlined),
              ),
              items: [
                for (final k in ContactKind.values)
                  DropdownMenuItem(value: k, child: Text(s.contactLabel(k.name))),
              ],
              onChanged: (k) => setState(() => _defaultContact = k ?? _defaultContact),
            ),
            section(s.feeSection),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _fee,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: s.monthlyFee, helperText: s.optional),
                    validator: numberValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cycle,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: s.daysPerCycle, helperText: s.optional),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return null;
                      final n = int.tryParse(t);
                      return n == null || n <= 0 ? s.invalidNumber : null;
                    },
                  ),
                ),
              ],
            ),
            section(s.weeklySchedule),
            Text(s.scheduleHelp, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in _schedule)
                  InputChip(
                    label: Text(
                        '${s.weekday(slot.weekday)} ${TimeOfDay(hour: slot.startMinutes ~/ 60, minute: slot.startMinutes % 60).format(context)}'),
                    onDeleted: () => setState(() => _schedule.remove(slot)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(s.addSlot),
                  onPressed: _addSlot,
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: Text(s.save)),
          ],
        ),
      ),
    );
  }
}
