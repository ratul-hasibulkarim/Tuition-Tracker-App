import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/student.dart';
import '../services/launcher.dart';
import '../services/trip_service.dart';
import '../state/settings_store.dart';

Future<void> showTripSheet(BuildContext context, Student student) {
  if (!student.hasLocation && student.address.isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.of(context).noLocation)));
    return Future.value();
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => TripSheet(student: student),
  );
}

/// Shows distance, travel time and an estimated bike fare, with buttons to
/// open Google Maps directions or a ride-share app.
class TripSheet extends StatefulWidget {
  const TripSheet({super.key, required this.student});

  final Student student;

  @override
  State<TripSheet> createState() => _TripSheetState();
}

class _TripSheetState extends State<TripSheet> {
  TripEstimate? _trip;
  bool _loading = true;
  bool _noLocation = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final st = widget.student;
    if (!st.hasLocation) {
      setState(() => _loading = false);
      return;
    }
    try {
      final pos = await TripService.currentPosition();
      if (pos == null) {
        setState(() {
          _loading = false;
          _noLocation = true;
        });
        return;
      }
      final trip = await TripService.estimate(
        fromLat: pos.latitude,
        fromLng: pos.longitude,
        toLat: st.latitude!,
        toLng: st.longitude!,
      );
      if (mounted) {
        setState(() {
          _trip = trip;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _noLocation = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final fare = context.watch<SettingsStore>().fare;
    final trip = _trip;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.tripTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(widget.student.address.isEmpty ? widget.student.name : widget.student.address,
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            if (_loading)
              Row(children: [
                const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text(s.findingLocation),
              ])
            else if (_noLocation)
              Text(s.locationDenied, style: TextStyle(color: theme.colorScheme.error))
            else if (trip != null) ...[
              Row(
                children: [
                  _Stat(label: s.distance, value: '${trip.km.toStringAsFixed(1)} km'),
                  _Stat(label: s.travelTime, value: '${trip.minutes.round()} min'),
                  _Stat(
                    label: s.bikeFare,
                    value: '৳${fare.estimate(km: trip.km, minutes: trip.minutes).round()}',
                    highlight: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(trip.live ? s.liveTraffic : s.roughEstimate,
                  style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Launcher.directions(widget.student),
              icon: const Icon(Icons.directions),
              label: Text(s.openMaps),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: Launcher.pathao,
                    icon: const Icon(Icons.two_wheeler),
                    label: Text(s.openPathao),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Launcher.uber(widget.student),
                    icon: const Icon(Icons.local_taxi_outlined),
                    label: Text(s.openUber),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(s.fareNote, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: highlight ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
