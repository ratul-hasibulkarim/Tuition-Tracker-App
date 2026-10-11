import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../services/ai_service.dart';
import '../state/backup_store.dart';
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
          header(s.backup),
          const _BackupCard(),
          header(s.fareRates),
          const Card(child: Padding(padding: EdgeInsets.all(16), child: _FareForm())),
          header(s.ai),
          const Card(child: Padding(padding: EdgeInsets.all(16), child: _AiForm())),
        ],
      ),
    );
  }
}

class _BackupCard extends StatelessWidget {
  const _BackupCard();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final backup = context.watch<BackupStore>();
    final locale = Localizations.localeOf(context).languageCode;
    final when = backup.lastBackup == null
        ? s.noBackupYet
        : s.lastBackupAt(DateFormat.yMMMd(locale).add_jm().format(backup.lastBackup!));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.backupHelp, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if (!backup.signedIn)
              FilledButton.icon(
                onPressed: backup.busy ? null : () => _signIn(context, backup),
                icon: const Icon(Icons.login),
                label: Text(s.signInGoogle),
              )
            else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(backup.email!),
                subtitle: Text('$when\n${s.autoBackupNote}'),
                isThreeLine: true,
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: backup.busy ? null : () => _backup(context, backup),
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: Text(s.backupNow),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: backup.busy ? null : () => _restore(context, backup),
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: Text(s.restoreBackup),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: backup.busy ? null : backup.signOut,
                  child: Text(s.signOut),
                ),
              ),
            ],
            if (backup.busy) const LinearProgressIndicator(),
            if (backup.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(backup.error!,
                    style: TextStyle(color: theme.colorScheme.error), maxLines: 3),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _signIn(BuildContext context, BackupStore backup) async {
    final s = S.of(context);
    final found = await backup.signIn();
    if (!found || !context.mounted) return;
    // Reinstalled or new phone: offer to bring the data back.
    final restore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.backupFoundTitle),
        content: Text(s.backupFoundBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.notNow)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.restore)),
        ],
      ),
    );
    if (restore == true && context.mounted) await _doRestore(context, backup);
  }

  Future<void> _backup(BuildContext context, BackupStore backup) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await backup.backupNow();
    messenger.showSnackBar(SnackBar(content: Text(ok ? s.backupDone : s.backupFailed)));
  }

  Future<void> _restore(BuildContext context, BackupStore backup) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.restoreConfirmTitle),
        content: Text(s.restoreConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.restore)),
        ],
      ),
    );
    if (ok == true && context.mounted) await _doRestore(context, backup);
  }

  Future<void> _doRestore(BuildContext context, BackupStore backup) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await backup.restore();
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? s.restoreDone : (backup.error == null ? s.noBackupFound : s.backupFailed)),
    ));
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

class _AiForm extends StatefulWidget {
  const _AiForm();

  @override
  State<_AiForm> createState() => _AiFormState();
}

class _AiFormState extends State<_AiForm> {
  late final SettingsStore _settings = context.read<SettingsStore>();
  late AiProvider _provider = _settings.aiProvider;
  late final _model = TextEditingController(text: _settings.aiModel);
  late final _key = TextEditingController(text: _settings.aiKey);
  bool _showKey = false;

  @override
  void dispose() {
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(s.aiHelp, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        DropdownButtonFormField<AiProvider>(
          initialValue: _provider,
          isExpanded: true,
          decoration: InputDecoration(labelText: s.aiProvider, isDense: true),
          items: [
            for (final p in AiProvider.values) DropdownMenuItem(value: p, child: Text(p.label)),
          ],
          onChanged: (p) => setState(() => _provider = p ?? _provider),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _model,
          decoration: InputDecoration(
            labelText: s.aiModel,
            hintText: _provider.defaultModel,
            helperText: s.optional,
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _key,
          obscureText: !_showKey,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: s.aiKey,
            isDense: true,
            suffixIcon: IconButton(
              icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showKey = !_showKey),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              FocusScope.of(context).unfocus();
              await _settings.setAi(_provider, _model.text, _key.text);
              messenger.showSnackBar(SnackBar(content: Text(s.saved)));
            },
            child: Text(s.save),
          ),
        ),
      ],
    );
  }
}
