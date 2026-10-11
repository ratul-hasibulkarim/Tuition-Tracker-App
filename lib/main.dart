import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'data/student_repository.dart';
import 'screens/home_screen.dart';
import 'state/backup_store.dart';
import 'state/settings_store.dart';
import 'state/student_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  final settings = SettingsStore();
  final repo = StudentRepository();
  final students = StudentStore(repo);
  await Future.wait([settings.load(), students.load()]);
  final backup = BackupStore(repo, students);
  // Silent sign-in + daily backup in the background; never blocks startup.
  backup.start();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: students),
        ChangeNotifierProvider.value(value: backup),
      ],
      child: const TuitionTrackerApp(),
    ),
  );
}

class TuitionTrackerApp extends StatefulWidget {
  const TuitionTrackerApp({super.key});

  @override
  State<TuitionTrackerApp> createState() => _TuitionTrackerAppState();
}

class _TuitionTrackerAppState extends State<TuitionTrackerApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back up changes when the teacher leaves the app.
    if (state == AppLifecycleState.paused) {
      context.read<BackupStore>().backupIfChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    return MaterialApp(
      title: 'Tuition Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: const [Locale('en'), Locale('bn')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomeScreen(),
    );
  }
}
