import 'package:flutter/material.dart';

import '../l10n/strings.dart';

/// "4:30 PM" / "৪:৩০ PM" for minutes after midnight.
String formatMinutes(BuildContext context, int minutes) {
  final t = TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60);
  return S.of(context).n(t.format(context));
}
