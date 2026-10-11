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
  final _search = TextEditingController();
  bool _searching = false;
  List<PickedLocation>? _results;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Looks up a typed address with the phone's built-in geocoder (free).
  Future<void> _runSearch() async {
    var q = _search.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    if (!q.toLowerCase().contains('bangladesh')) q = '$q, Bangladesh';
    setState(() {
      _searching = true;
      _results = null;
    });
    final found = <PickedLocation>[];
    try {
      final geo = Geocoding();
      final locations = await geo.locationFromAddress(q);
      for (final l in locations.take(5)) {
        var label = _search.text.trim();
        try {
          final marks = await geo.placemarkFromCoordinates(l.latitude, l.longitude);
          if (marks.isNotEmpty) label = _describe(marks.first);
        } catch (_) {}
        found.add(PickedLocation(LatLng(l.latitude, l.longitude), label));
      }
    } catch (_) {
      // No match: show "no places found".
    }
    if (!mounted) return;
    setState(() {
      _searching = false;
      _results = found;
    });
    if (found.length == 1) _goTo(found.single);
  }

  void _goTo(PickedLocation p) {
    _map?.animateCamera(CameraUpdate.newLatLngZoom(p.latLng, 17));
    setState(() {
      _center = p.latLng;
      _results = null;
    });
  }

  static String _describe(Placemark m) => [m.name, m.street, m.subLocality, m.locality]
      .whereType<String>()
      .where((p) => p.trim().isNotEmpty)
      .toSet()
      .join(', ');

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
      if (marks.isNotEmpty) address = _describe(marks.first);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(8),
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _runSearch(),
                    decoration: InputDecoration(
                      hintText: s.searchAddress,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _runSearch),
                    ),
                  ),
                ),
                if (_results != null)
                  Card(
                    margin: const EdgeInsets.only(top: 4),
                    child: _results!.isEmpty
                        ? ListTile(title: Text(s.noResults))
                        : Column(
                            children: [
                              for (final r in _results!)
                                ListTile(
                                  leading: const Icon(Icons.place_outlined),
                                  title: Text(r.address.isEmpty ? _search.text : r.address),
                                  onTap: () => _goTo(r),
                                ),
                            ],
                          ),
                  )
                else
                  Card(
                    margin: const EdgeInsets.only(top: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(s.moveMapHint, textAlign: TextAlign.center),
                    ),
                  ),
              ],
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
