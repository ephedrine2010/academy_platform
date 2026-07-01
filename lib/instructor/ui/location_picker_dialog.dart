import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;

import '../../theme/app_theme.dart';
import '../data/latlng_parser.dart';

/// Default map centre when no point is pre-selected — Riyadh.
const ll.LatLng _kFallbackCentre = ll.LatLng(24.7136, 46.6753);

/// Opens a dialog with an interactive OpenStreetMap. The admin can search for an
/// address or tap to drop a pin; "Use this location" returns the picked [LatLng]
/// (the project's own coordinate type, from [latlng_parser]). Returns `null` on
/// cancel.
///
/// Uses `flutter_map` + OSM tiles and the Nominatim geocoder — no API key /
/// billing, and works on web (the primary target), unlike resolving Google Maps
/// share links which is blocked by browser CORS. See
/// documentation/instructor/attendance_implementation.md.
Future<LatLng?> showLocationPickerDialog(
  BuildContext context, {
  LatLng? initial,
}) {
  return showDialog<LatLng>(
    context: context,
    builder: (_) => _LocationPickerDialog(initial: initial),
  );
}

/// A geocoder hit from Nominatim.
class _Place {
  const _Place(this.label, this.point);
  final String label;
  final ll.LatLng point;
}

class _LocationPickerDialog extends StatefulWidget {
  const _LocationPickerDialog({this.initial});

  final LatLng? initial;

  @override
  State<_LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<_LocationPickerDialog> {
  late final MapController _map;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<_Place> _results = const [];
  bool _searching = false;
  bool _locating = false;
  ll.LatLng? _picked;

  @override
  void initState() {
    super.initState();
    _map = MapController();
    final i = widget.initial;
    if (i != null) _picked = ll.LatLng(i.lat, i.lng);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 3) {
      setState(() => _results = const []);
      return;
    }
    // Debounce to respect Nominatim's ~1 req/sec usage policy.
    _debounce = Timer(const Duration(milliseconds: 600), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeQueryComponent(query)}&format=jsonv2&limit=6',
      );
      final res = await http.get(
        uri,
        // Nominatim requires a descriptive User-Agent identifying the app.
        headers: const {'User-Agent': 'AcademyPlatform/1.0 (location-picker)'},
      );
      if (!mounted) return;
      if (res.statusCode != 200) {
        setState(() {
          _results = const [];
          _searching = false;
        });
        return;
      }
      final data = jsonDecode(res.body) as List<dynamic>;
      final places = <_Place>[];
      for (final item in data) {
        final m = item as Map<String, dynamic>;
        final lat = double.tryParse('${m['lat']}');
        final lng = double.tryParse('${m['lon']}');
        if (lat == null || lng == null) continue;
        places.add(_Place('${m['display_name']}', ll.LatLng(lat, lng)));
      }
      setState(() {
        _results = places;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _searching = false;
      });
    }
  }

  /// Centre the map on the device's current position. On web this triggers the
  /// browser's location permission prompt; on native it uses OS location.
  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('Turn on location services to use this.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _snack('Location permission was denied.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final point = ll.LatLng(pos.latitude, pos.longitude);
      setState(() {
        _picked = point;
        _results = const [];
      });
      _map.move(point, 16);
    } catch (_) {
      _snack('Could not get your location.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectPlace(_Place place) {
    FocusScope.of(context).unfocus();
    setState(() {
      _picked = place.point;
      _results = const [];
      _searchCtrl.text = place.label;
    });
    _map.move(place.point, 16);
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
              child: Row(
                children: [
                  const Icon(TablerIcons.map_pin, size: 18, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Text(
                    'Pick the venue location',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(TablerIcons.x, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) {
                  _debounce?.cancel();
                  if (v.trim().length >= 3) _search(v.trim());
                },
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(TablerIcons.search, size: 18),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (_searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(TablerIcons.x, size: 16),
                              onPressed: () {
                                _debounce?.cancel();
                                setState(() {
                                  _searchCtrl.clear();
                                  _results = const [];
                                });
                              },
                            )
                          : null),
                  labelText: 'Search for an address or place',
                  hintText: 'e.g. King Fahd Road, Riyadh',
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    child: FlutterMap(
                      mapController: _map,
                      options: MapOptions(
                        initialCenter: picked ?? _kFallbackCentre,
                        initialZoom: picked != null ? 16 : 11,
                        onTap: (_, point) {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            _picked = point;
                            _results = const [];
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.academy.platform',
                        ),
                        if (picked != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: picked,
                                width: 40,
                                height: 40,
                                alignment: Alignment.topCenter,
                                child: const Icon(
                                  TablerIcons.map_pin_filled,
                                  color: AppColors.red,
                                  size: 36,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Material(
                      color: AppColors.surface,
                      elevation: 3,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _locating ? null : _useMyLocation,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: _locating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(
                                  TablerIcons.current_location,
                                  size: 20,
                                  color: AppColors.teal,
                                ),
                        ),
                      ),
                    ),
                  ),
                  if (_results.isNotEmpty)
                    Positioned(
                      left: 8,
                      right: 8,
                      top: 8,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(10),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final p = _results[i];
                              return ListTile(
                                dense: true,
                                leading: const Icon(TablerIcons.map_pin,
                                    size: 18, color: AppColors.teal),
                                title: Text(
                                  p.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(fontSize: 12),
                                ),
                                onTap: () => _selectPlace(p),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      picked == null
                          ? 'Search above, or tap the map to drop a pin.'
                          : '${picked.latitude.toStringAsFixed(6)}, '
                              '${picked.longitude.toStringAsFixed(6)}',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight:
                            picked == null ? FontWeight.w500 : FontWeight.w700,
                        color: picked == null ? AppColors.muted : AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: picked == null
                        ? null
                        : () => Navigator.of(context).pop(
                              LatLng(picked.latitude, picked.longitude),
                            ),
                    icon: const Icon(TablerIcons.check, size: 18),
                    label: const Text('Use this location'),
                    style:
                        FilledButton.styleFrom(backgroundColor: AppColors.teal),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
