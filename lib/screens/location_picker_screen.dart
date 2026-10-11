import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../l10n/strings.dart';
import '../services/trip_service.dart';

class PickedLocation {
  const PickedLocation(this.latLng, this.address);

  final LatLng latLng;

  /// Address suggested by the phone's built-in geocoder (may be empty).
  final String address;
}

/// Full-screen map with a fixed centre pin; the teacher moves the map
/// until the pin is on the student's house.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initial});

  final LatLng? initial;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _dhaka = LatLng(23.8103, 90.4125);
  GoogleMapController? _map;
  late LatLng _center = widget.initial ?? _dhaka;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial == null) _goToMyLocation();
  }

  Future<void> _goToMyLocation() async {
    final pos = await TripService.currentPosition();
    if (pos == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.of(context).locationDenied)));
      }
      return;
    }
    final target = LatLng(pos.latitude, pos.longitude);
    _map?.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
    setState(() => _center = target);
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    var address = '';
    try {
      final marks = await Geocoding().placemarkFromCoordinates(
        _center.latitude,
        _center.longitude,
      );
      if (marks.isNotEmpty) {
        final m = marks.first;
        address = [m.name, m.subLocality, m.locality]
            .whereType<String>()
            .where((p) => p.trim().isNotEmpty)
            .toSet()
            .join(', ');
      }
    } catch (_) {
      // Geocoding is a nice-to-have; the coordinates are what matter.
    }
    if (mounted) Navigator.of(context).pop(PickedLocation(_center, address));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.chooseLocation)),
      body: Stack(
        alignment: Alignment.center,
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 16),
            onMapCreated: (c) => _map = c,
            onCameraMove: (p) => _center = p.target,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          // The pin's tip sits on the map centre.
          Padding(
            padding: const EdgeInsets.only(bottom: 48),
            child: Icon(Icons.location_pin, size: 48, color: theme.colorScheme.primary),
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(s.moveMapHint, textAlign: TextAlign.center),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 96,
            child: FloatingActionButton.small(
              heroTag: 'myLocation',
              tooltip: s.myLocation,
              onPressed: _goToMyLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: FilledButton.icon(
              onPressed: _saving ? null : _confirm,
              icon: const Icon(Icons.check),
              label: Text(s.useThisLocation),
            ),
          ),
        ],
      ),
    );
  }
}
