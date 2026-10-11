import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/settings_store.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final settings = context.watch<SettingsStore>();

    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(t,
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          header(s.appearance),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.theme),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(value: ThemeMode.system, label: Text(s.themeSystem), icon: const Icon(Icons.brightness_auto)),
                      ButtonSegment(value: ThemeMode.light, label: Text(s.themeLight), icon: const Icon(Icons.light_mode_outlined)),
                      ButtonSegment(value: ThemeMode.dark, label: Text(s.themeDark), icon: const Icon(Icons.dark_mode_outlined)),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (v) => settings.setThemeMode(v.first),
                  ),
                  const SizedBox(height: 16),
                  Text(s.language),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('English')),
                      ButtonSegment(value: 'bn', label: Text('বাংলা')),
                    ],
                    selected: {settings.locale.languageCode},
                    onSelectionChanged: (v) => settings.setLocale(Locale(v.first)),
                  ),
                ],
              ),
            ),
          ),
          header(s.fareRates),
          const Card(child: Padding(padding: EdgeInsets.all(16), child: _FareForm())),
          header(s.backup),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: Text(s.backupComing),
            ),
          ),
        ],
      ),
    );
  }
}

class _FareForm extends StatefulWidget {
  const _FareForm();

  @override
  State<_FareForm> createState() => _FareFormState();
}

class _FareFormState extends State<_FareForm> {
  late final FareRates _initial = context.read<SettingsStore>().fare;
  late final _base = TextEditingController(text: _fmt(_initial.base));
  late final _km = TextEditingController(text: _fmt(_initial.perKm));
  late final _min = TextEditingController(text: _fmt(_initial.perMinute));
  late final _minimum = TextEditingController(text: _fmt(_initial.minimum));

  static String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [_base, _km, _min, _minimum]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final s = S.of(context);
    double parse(TextEditingController c, double fallback) =>
        double.tryParse(c.text.trim()) ?? fallback;
    context.read<SettingsStore>().setFare(FareRates(
          base: parse(_base, _initial.base),
          perKm: parse(_km, _initial.perKm),
          perMinute: parse(_min, _initial.perMinute),
          minimum: parse(_minimum, _initial.minimum),
        ));
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.saved)));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    Widget field(TextEditingController c, String label) => Expanded(
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label, isDense: true),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(children: [field(_base, s.baseFare), const SizedBox(width: 12), field(_km, s.perKm)]),
        const SizedBox(height: 12),
        Row(children: [field(_min, s.perMinute), const SizedBox(width: 12), field(_minimum, s.minimumFare)]),
        const SizedBox(height: 12),
        FilledButton(onPressed: _save, child: Text(s.save)),
      ],
    );
  }
}
