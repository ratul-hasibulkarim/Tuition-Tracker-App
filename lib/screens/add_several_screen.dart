import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/student.dart';
import '../state/student_store.dart';
import 'location_picker_screen.dart';

/// Coaching centres: add a whole batch at once. Details typed here are
/// shared; each student can be edited later for phone numbers etc.
class AddSeveralScreen extends StatefulWidget {
  const AddSeveralScreen({super.key});

  @override
  State<AddSeveralScreen> createState() => _AddSeveralScreenState();
}

class _AddSeveralScreenState extends State<AddSeveralScreen> {
  final _form = GlobalKey<FormState>();
  final _names = TextEditingController();
  final _batch = TextEditingController();
  final _className = TextEditingController();
  final _subjects = TextEditingController();
  final _address = TextEditingController();
  final _fee = TextEditingController();
  final _cycle = TextEditingController();
  LatLng? _location;

  @override
  void dispose() {
    for (final c in [_names, _batch, _className, _subjects, _address, _fee, _cycle]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _nameList =>
      _names.text.split('\n').map((n) => n.trim()).where((n) => n.isNotEmpty).toList();

  Future<void> _pickLocation() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: _location)),
    );
    if (picked == null) return;
    setState(() {
      _location = picked.latLng;
      if (_address.text.trim().isEmpty) _address.text = picked.address;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final s = S.of(context);
    final store = context.read<StudentStore>();
    final messenger = ScaffoldMessenger.of(context);
    final students = [
      for (final name in _nameList)
        Student(
          name: name,
          batch: _batch.text.trim(),
          className: _className.text.trim(),
          subjects: _subjects.text.trim(),
          address: _address.text.trim(),
          latitude: _location?.latitude,
          longitude: _location?.longitude,
          monthlyFee: double.tryParse(_fee.text.trim()),
          daysPerCycle: int.tryParse(_cycle.text.trim()),
        ),
    ];
    await store.addMany(students);
    messenger.showSnackBar(SnackBar(content: Text(s.studentsAdded(students.length))));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.addSeveral),
        actions: [TextButton(onPressed: _save, child: Text(s.save))],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextFormField(
              controller: _batch,
              decoration: InputDecoration(
                labelText: s.batch,
                prefixIcon: const Icon(Icons.groups_outlined),
              ),
              validator: (v) => (v?.trim().isEmpty ?? true) ? s.nameRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _names,
              minLines: 5,
              maxLines: 12,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: s.namesOnePerLine,
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() {}),
              validator: (_) => _nameList.isEmpty ? s.nameRequired : null,
            ),
            if (_nameList.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(s.batchStudents(_nameList.length), style: theme.textTheme.bodySmall),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Text(s.sharedDetails,
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
            ),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _className,
                  decoration: InputDecoration(labelText: s.classLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _subjects,
                  decoration: InputDecoration(labelText: s.subjectsLabel),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration: InputDecoration(labelText: s.address, prefixIcon: const Icon(Icons.home_outlined)),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: Icon(_location != null ? Icons.check_circle : Icons.map_outlined),
              label: Text(_location != null ? s.locationPicked : s.pickOnMap),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _fee,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: s.monthlyFee),
                  validator: (v) => (v?.trim().isNotEmpty ?? false) && double.tryParse(v!.trim()) == null
                      ? s.invalidNumber
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _cycle,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.daysPerCycle),
                  validator: (v) => (v?.trim().isNotEmpty ?? false) && (int.tryParse(v!.trim()) ?? 0) <= 0
                      ? s.invalidNumber
                      : null,
                ),
              ),
            ]),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: Text(s.save)),
          ],
        ),
      ),
    );
  }
}
