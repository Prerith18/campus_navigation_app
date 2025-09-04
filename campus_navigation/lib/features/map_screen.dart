// lib/features/map_screen.dart
// (unchanged header comments omitted for brevity)

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

import 'package:campus_navigation/models/campus_poi.dart';
import 'package:campus_navigation/services/campus_poi_repository.dart';

class MapScreen extends StatefulWidget {
  final String searchQuery;
  final double? searchLat;
  final double? searchLng;
  final bool isAdmin;
  final bool autoRouteOnOpen;

  const MapScreen({
    super.key,
    this.searchQuery = '',
    this.searchLat,
    this.searchLng,
    this.isAdmin = false,
    this.autoRouteOnOpen = false,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final PageController _pageCtrl = PageController(viewportFraction: 0.82);
  final TextEditingController _adminSearchCtrl = TextEditingController();

  static const String apiKey = "AIzaSyAsHYoxe5t5A8Zm8tPogYOfWFjAtyDionw";
  static const LatLng campusCenter = LatLng(52.6219, -1.1244);

  static const String bodsSiriUrl =
      "https://data.bus-data.dft.gov.uk/api/v1/datafeed/18865/?api_key=1d4baf6fa7186850abd35eeff4b7f8af29a78fc1";

  LatLng? _currentLocation;
  LatLng? _selectedLocation;
  int _currentIndex = 0;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _searchedVisible = false;

  RouteInfo? _routeInfo;
  bool _isWheelchairRoute = false;

  final List<CampusPoi> _pois = [];
  StreamSubscription<List<CampusPoi>>? _poiSub;

  // Live buses
  bool _liveOn = false;
  bool _didAutoFocusBuses = false;
  Timer? _busPollTimer;
  final Map<String, LatLng> _busPrevPos = {};
  final Map<String, Timer> _busAnimTimers = {};
  BitmapDescriptor? _emojiIcon;

  // ---- Map style (dark mode support)
  Brightness? _lastBrightness;

  // A compact dark style that keeps labels readable
  static const String _mapStyleDark = '''
[
  {"elementType":"geometry","stylers":[{"color":"#242f3e"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#263c3f"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#6b9a76"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414e"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ca5b3"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#746855"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1f2835"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f3d19c"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]},
  {"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#515c6d"}]},
  {"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#17263c"}]}
]
''';

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadEmojiIcon();
    _subscribePois();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.searchLat != null && widget.searchLng != null) {
        final coords = LatLng(widget.searchLat!, widget.searchLng!);
        await _setDestination(
          coords,
          title: widget.searchQuery.isEmpty ? 'Selected location' : widget.searchQuery,
          addMarker: true,
        );

        if (widget.autoRouteOnOpen) {
          Future.delayed(const Duration(milliseconds: 100), () {
            _showRoute(wheelchair: false);
          });
        }
      }

      setState(() {
        _markers.removeWhere((m) {
          final id = m.markerId.value;
          return !(id == 'current_location' || id == 'searched' || id.startsWith('bus_'));
        });
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyMapStyleForTheme());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _poiSub?.cancel();
    _busPollTimer?.cancel();
    for (final t in _busAnimTimers.values) {
      t.cancel();
    }
    _busAnimTimers.clear();
    super.dispose();
  }

  // ---------- Firestore POIs ----------
  void _subscribePois() {
    _poiSub = CampusPoiRepository.instance.streamAllActiveOrdered().listen((list) {
      if (!mounted) return;
      setState(() {
        _pois
          ..clear()
          ..addAll(list);
      });
    }, onError: (e) => debugPrint('POI stream error: $e'));
  }

  // ---------- Location ----------
  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _toast('Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _toast('Location permission denied.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _toast('Location permission permanently denied.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        final next = <Marker>{..._markers}
          ..removeWhere((m) => m.markerId.value == 'current_location');
        next.add(Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(title: 'You are here'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ));
        _markers = next;
      });
    } catch (_) {
      _toast('Failed to get location');
    }
  }

  Future<void> _animateTo(LatLng latLng, {double zoom = 17}) async {
    final c = await _controller.future;
    await c.animateCamera(CameraUpdate.newLatLngZoom(latLng, zoom));
  }

  Future<void> _animateToCurrent() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        await _animateTo(LatLng(last.latitude, last.longitude), zoom: 17);
      }
      final fresh = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 6),
      );
      final here = LatLng(fresh.latitude, fresh.longitude);
      if (!mounted) return;
      setState(() {
        final next = <Marker>{..._markers}
          ..removeWhere((m) => m.markerId.value == 'current_location');
        next.add(Marker(
          markerId: const MarkerId('current_location'),
          position: here,
          infoWindow: const InfoWindow(title: 'You are here'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ));
        _markers = next;
        _currentLocation = here;
      });
      await _animateTo(here, zoom: 17);
    } catch (_) {
      _toast('Couldn’t get your location. Check GPS & permissions.');
    }
  }

  // ---------- Selection / clear ----------
  Future<void> _setDestination(LatLng coords, {String? title, bool addMarker = false}) async {
    setState(() {
      _selectedLocation = coords;
      _searchedVisible = addMarker;

      final next = <Marker>{..._markers}..removeWhere((m) => m.markerId.value == 'searched');

      if (_searchedVisible) {
        next.add(Marker(
          markerId: const MarkerId('searched'),
          position: coords,
          infoWindow: title == null ? const InfoWindow() : InfoWindow(title: title),
          onTap: widget.isAdmin ? _openEditorForSearched : null,
        ));
      }
      _markers = next;

      _polylines.clear();
      _routeInfo = null;
    });
    await _animateTo(coords);
  }

  void _clearNavigation() {
    setState(() {
      _selectedLocation = null;
      _searchedVisible = false;
      _polylines.clear();
      _routeInfo = null;
      _markers.removeWhere((m) => m.markerId.value == 'searched');
    });
  }

  void _clearSearchedMarker() {
    setState(() {
      _searchedVisible = false;
      _markers.removeWhere((m) => m.markerId.value == 'searched');
      _polylines.clear();
      _routeInfo = null;
    });
  }

  // ---------- Directions ----------
  Timer? _routeDebounce;
  Future<void> _showRoute({required bool wheelchair}) async {
    if (_selectedLocation == null) {
      _toast('Choose a place first.');
      return;
    }
    if (_currentLocation == null) {
      await _initLocation();
      if (_currentLocation == null) {
        _toast('Enable location to get directions.');
        return;
      }
    }

    _routeDebounce?.cancel();
    _routeDebounce = Timer(const Duration(milliseconds: 200), () async {
      try {
        final route = await _getRouteWithStats(_currentLocation!, _selectedLocation!, wheelchair: wheelchair);
        setState(() {
          _isWheelchairRoute = wheelchair;
          _routeInfo = route;
          _polylines = {
            Polyline(
              polylineId: PolylineId(wheelchair ? 'wheelchair' : 'walking'),
              points: route.points,
              color: wheelchair
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.primary,
              width: 6,
              patterns: [PatternItem.dot, PatternItem.gap(12)],
            ),
          };
        });
        await _fitBoundsToPolyline(route.points);
      } catch (e) {
        _toast(e.toString());
      }
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<RouteInfo> _getRouteWithStats(LatLng origin, LatLng dest, {required bool wheelchair}) async {
    final params = {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${dest.latitude},${dest.longitude}',
      'mode': 'walking',
      'key': apiKey,
    };
    final url = Uri.https('maps.googleapis.com', '/maps/api/directions/json', params);
    final resp = await http.get(url);
    if (resp.statusCode != 200) throw HttpException('HTTP ${resp.statusCode}');
    final data = json.decode(resp.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') {
      final em = (data['error_message'] as String?) ?? '';
      throw Exception('Directions: ${data['status']} ${em.isNotEmpty ? '· $em' : ''}');
    }

    final routes = (data['routes'] as List);
    if (routes.isEmpty) throw Exception('No routes');
    final route0 = routes.first as Map<String, dynamic>;
    final legs = (route0['legs'] as List);
    String distanceText = '', durationText = '';
    int distanceMeters = 0, durationSeconds = 0;
    if (legs.isNotEmpty) {
      final leg0 = legs.first as Map<String, dynamic>;
      final dist = (leg0['distance'] as Map<String, dynamic>);
      final dur = (leg0['duration'] as Map<String, dynamic>);
      distanceText = dist['text'] as String? ?? '';
      durationText = dur['text'] as String? ?? '';
      distanceMeters = (dist['value'] as num?)?.toInt() ?? 0;
      durationSeconds = (dur['value'] as num?)?.toInt() ?? 0;
    }

    final encoded = route0['overview_polyline']['points'] as String;
    final points = _decodePolyline(encoded);
    return RouteInfo(
      points: points,
      distanceText: distanceText,
      durationText: durationText,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> poly = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      poly.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return poly;
  }

  Future<void> _fitBoundsToPolyline(List<LatLng> pts) async {
    if (pts.isEmpty) return;
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final c = await _controller.future;
    await c.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  // ---------- Search (Places) ----------
  Future<void> _searchPlace(String query) async {
    if (query.trim().isEmpty) return;
    try {
      final url = Uri.https('maps.googleapis.com', '/maps/api/place/textsearch/json', {
        'query': query,
        'location': '${campusCenter.latitude},${campusCenter.longitude}',
        'radius': '2000',
        'key': apiKey,
      });
      final resp = await http.get(url);
      if (resp.statusCode != 200) throw HttpException('HTTP ${resp.statusCode}');
      final data = json.decode(resp.body) as Map<String, dynamic>;
      if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
        final result = (data['results'] as List).first as Map<String, dynamic>;
        final loc = result['geometry']['location'] as Map<String, dynamic>;
        final name = (result['name'] as String?) ?? query;
        final latLng = LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
        await _setDestination(latLng, title: name, addMarker: true);
      } else {
        _toast('No results for "$query" (${data['status']})');
      }
    } catch (_) {
      _toast('Search failed. Check network/API key.');
    }
  }

  // ---------- Admin editor ----------
  void _openEditorForSearched() {
    if (!widget.isAdmin || _selectedLocation == null) return;
    _openPoiEditor(initialPos: _selectedLocation!);
  }

  Future<void> _openPoiEditor({LatLng? initialPos, CampusPoi? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final imageUrl = TextEditingController(text: existing?.imageUrl ?? '');
    final address = TextEditingController(text: existing?.address ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final website = TextEditingController(text: existing?.website ?? '');
    final closesAt = TextEditingController(text: existing?.closesAt ?? '');
    final order = TextEditingController(text: (existing?.order ?? 0).toString());
    final category = TextEditingController(text: existing?.category ?? '');
    final lat = TextEditingController(
        text: (existing?.lat ?? initialPos?.latitude ?? campusCenter.latitude).toStringAsFixed(6));
    final lng = TextEditingController(
        text: (existing?.lng ?? initialPos?.longitude ?? campusCenter.longitude).toStringAsFixed(6));
    bool isOpenNow = existing?.isOpenNow ?? true;
    bool active = existing?.active ?? true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? 'Publish carousel' : 'Edit carousel',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              Row(children: [
                Expanded(child: TextField(controller: lat, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: lng, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.number)),
              ]),
              TextField(controller: imageUrl, decoration: const InputDecoration(labelText: 'Image URL')),
              TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
              TextField(controller: website, decoration: const InputDecoration(labelText: 'Website')),
              TextField(controller: closesAt, decoration: const InputDecoration(labelText: 'Closes At (text)')),
              TextField(controller: order, decoration: const InputDecoration(labelText: 'Order (int)')),
              TextField(controller: category, decoration: const InputDecoration(labelText: 'Category (optional)')),
              SwitchListTile(value: isOpenNow, onChanged: (v) => isOpenNow = v, title: const Text('Open Now')),
              SwitchListTile(value: active, onChanged: (v) => active = v, title: const Text('Active')),

              const SizedBox(height: 12),
              Row(
                children: [
                  if (existing != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(color: Theme.of(context).colorScheme.error),
                      ),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete carousel?'),
                            content: Text('Remove "${existing.name}" from the map?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        ) ?? false;

                        if (!ok) return;
                        try {
                          await CampusPoiRepository.instance.deleteById(existing.id);
                          if (mounted) _clearSearchedMarker();
                          if (context.mounted) Navigator.pop(context);
                          _toast('Deleted "${existing.name}"');
                        } catch (e) {
                          _toast('Delete failed: $e');
                        }
                      },
                    ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    child: const Text('Publish'),
                    onPressed: () async {
                      try {
                        final dLat = double.parse(lat.text.trim());
                        final dLng = double.parse(lng.text.trim());
                        final ord = int.tryParse(order.text.trim()) ?? 0;

                        final poi = CampusPoi(
                          id: existing?.id ?? '',
                          name: name.text.trim(),
                          lat: dLat,
                          lng: dLng,
                          imageUrl: imageUrl.text.trim(),
                          address: address.text.trim().isEmpty ? null : address.text.trim(),
                          phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                          website: website.text.trim().isEmpty ? null : website.text.trim(),
                          hours: existing?.hours ?? const {},
                          isOpenNow: isOpenNow,
                          closesAt: closesAt.text.trim(),
                          order: ord,
                          active: active,
                          category: category.text.trim().isEmpty ? null : category.text.trim(),
                        );

                        await CampusPoiRepository.instance.upsert(poi);

                        if (mounted) _clearSearchedMarker();
                        if (context.mounted) Navigator.pop(context);
                        _toast('Published "${poi.name}"');
                      } catch (e) {
                        _toast('Publish failed: $e');
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteFromCard(CampusPoi poi) async {
    if (!widget.isAdmin) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete carousel?'),
        content: Text('Remove "${poi.name}" from the map?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    try {
      await CampusPoiRepository.instance.deleteById(poi.id);
      if (mounted) _clearSearchedMarker();
      _toast('Deleted "${poi.name}"');
    } catch (e) {
      _toast('Delete failed: $e');
    }
  }

  // ---------- Live buses ----------
  void _startLiveBuses() {
    if (_liveOn) return;
    _liveOn = true;
    _didAutoFocusBuses = false;
    _animateTo(campusCenter, zoom: 13);
    _busPollTimer?.cancel();
    _busPollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchAndRenderSiri());
    _fetchAndRenderSiri();
    setState(() {});
  }

  void _stopLiveBuses() {
    _busPollTimer?.cancel();
    _busPollTimer = null;
    _liveOn = false;
    for (final t in _busAnimTimers.values) {
      t.cancel();
    }
    _busAnimTimers.clear();
    _busPrevPos.clear();
    setState(() {
      _markers.removeWhere((m) => m.markerId.value.startsWith('bus_'));
    });
  }

  Future<void> _fetchAndRenderSiri() async {
    try {
      final resp = await http.get(Uri.parse(bodsSiriUrl));
      if (resp.statusCode != 200) {
        _toast('SIRI feed HTTP ${resp.statusCode}');
        return;
      }
      final doc = xml.XmlDocument.parse(resp.body);
      final vehicleActivities = doc.findAllElements('VehicleActivity', namespace: '*');

      final idsNow = <String>{};
      LatLng? firstPos;
      int totalCount = 0;

      for (final va in vehicleActivities) {
        final mvjIter = va.findAllElements('MonitoredVehicleJourney', namespace: '*');
        if (mvjIter.isEmpty) continue;
        final mvj = mvjIter.first;

        final idRaw = _textOfFirst(mvj, 'VehicleRef') ?? _textOfFirst(va, 'VehicleRef');
        if (idRaw == null || idRaw.trim().isEmpty) continue;
        final id = idRaw.trim();

        final locIter = mvj.findAllElements('VehicleLocation', namespace: '*');
        if (locIter.isEmpty) continue;
        final loc = locIter.first;

        final latStr = _textOfFirst(loc, 'Latitude');
        final lngStr = _textOfFirst(loc, 'Longitude');
        if (latStr == null || lngStr == null) continue;

        final lat = double.tryParse(latStr);
        final lng = double.tryParse(lngStr);
        if (lat == null || lng == null) continue;

        final next = LatLng(lat, lng);
        totalCount++;
        final markerId = 'bus_$id';
        idsNow.add(markerId);
        firstPos ??= next;

        final prev = _busPrevPos[id];
        _smoothMove(
          id: id,
          markerId: markerId,
          from: prev ?? next,
          to: next,
          icon: _emojiIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        );
        _busPrevPos[id] = next;
      }

      if (!mounted) return;

      setState(() {
        _markers.removeWhere((m) => m.markerId.value.startsWith('bus_') && !idsNow.contains(m.markerId.value));
      });

      if (!_didAutoFocusBuses && firstPos != null) {
        final c = await _controller.future;
        await c.animateCamera(CameraUpdate.newLatLngZoom(firstPos!, 12));
        _didAutoFocusBuses = true;
      }

      if (totalCount == 0) {
        _toast('No vehicles in the live feed right now.');
      }
    } catch (e) {
      _toast('Could not parse live bus feed.');
    }
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = (b.latitude - a.latitude) * pi / 180.0;
    final dLng = (b.longitude - a.longitude) * pi / 180.0;
    final la1 = a.latitude * pi / 180.0;
    final la2 = b.latitude * pi / 180.0;

    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(la1) * cos(la2) * sin(dLng / 2) * sin(dLng / 2);

    return 2 * R * asin(sqrt(h));
  }

  void _smoothMove({
    required String id,
    required String markerId,
    required LatLng from,
    required LatLng to,
    required BitmapDescriptor icon,
    int durationMs = 1800,
    int stepMs = 60,
  }) {
    _busAnimTimers[id]?.cancel();
    final dist = _distanceMeters(from, to);
    if (dist < 2 || dist > 2000) {
      _putEmojiMarker(markerId, to, icon);
      return;
    }
    final totalSteps = (durationMs / stepMs).ceil();
    int step = 0;
    _busAnimTimers[id] = Timer.periodic(Duration(milliseconds: stepMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      step++;
      final t = (step / totalSteps).clamp(0.0, 1.0);
      final lat = from.latitude + (to.latitude - from.latitude) * t;
      final lng = from.longitude + (to.longitude - from.longitude) * t;
      final pos = LatLng(lat, lng);
      _putEmojiMarker(markerId, pos, icon);
      if (step >= totalSteps) timer.cancel();
    });
  }

  void _putEmojiMarker(String markerId, LatLng pos, BitmapDescriptor icon) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == markerId);
      _markers.add(Marker(
        markerId: MarkerId(markerId),
        position: pos,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        zIndex: 1000.0,
        icon: icon,
      ));
    });
  }

  Future<void> _loadEmojiIcon() async {
    try {
      _emojiIcon = await _makeEmojiMarker('🚌', fontSize: 56);
    } catch (_) {
      _emojiIcon = null;
    }
  }

  Future<BitmapDescriptor> _makeEmojiMarker(String emoji, {double fontSize = 48}) async {
    final tp = TextPainter(
      text: TextSpan(text: emoji, style: TextStyle(fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    final double w = tp.width + 12;
    final double h = tp.height + 12;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final bg = Paint()..color = Colors.white.withOpacity(0.92);
    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(14));
    canvas.drawRRect(rrect, bg);
    tp.paint(canvas, Offset((w - tp.width) / 2, (h - tp.height) / 2));
    final img = await recorder.endRecording().toImage(w.ceil(), h.ceil());
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  String? _textOfFirst(xml.XmlElement parent, String localName) {
    final n = parent.findAllElements(localName, namespace: '*');
    if (n.isEmpty) return null;
    final txt = n.first.text.trim();
    return txt.isEmpty ? null : txt;
  }

  // ---- Map style applier
  Future<void> _applyMapStyleForTheme() async {
    if (!_controller.isCompleted) return;
    final brightness = Theme.of(context).brightness;
    if (_lastBrightness == brightness) return;
    final c = await _controller.future;
    await c.setMapStyle(brightness == Brightness.dark ? _mapStyleDark : null);
    _lastBrightness = brightness;
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final markersToShow =
    _searchedVisible ? _markers : _markers.where((m) => m.markerId.value != 'searched').toSet();

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: campusCenter, zoom: 16),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: markersToShow,
            polylines: _polylines,
            onMapCreated: (controller) async {
              if (!_controller.isCompleted) {
                _controller.complete(controller);
              }
              await _applyMapStyleForTheme();
            },
          ),

          // Admin-only search bar
          if (widget.isAdmin)
            Positioned(
              left: 16,
              right: 16,
              top: MediaQuery.of(context).padding.top + 12,
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(12),
                child: TextField(
                  controller: _adminSearchCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (q) => _searchPlace(q),
                  decoration: InputDecoration(
                    hintText: 'Search a building...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _adminSearchCtrl.clear();
                        _clearNavigation(); // clears marker + route
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.cardColor,
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ),

          // Distance/time chip
          if (_routeInfo != null)
            Positioned(
              right: 16,
              bottom: 320,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
                  border: Border.all(
                    color: _isWheelchairRoute
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.primary,
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.route, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _routeInfo!.distanceText.isNotEmpty
                              ? _routeInfo!.distanceText
                              : _formatDistance(_routeInfo!.distanceMeters),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_isWheelchairRoute ? Icons.accessible : Icons.timer, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _routeInfo!.durationText.isNotEmpty
                              ? _routeInfo!.durationText
                              : _formatDuration(_routeInfo!.durationSeconds),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Carousel (both user & admin)
          if (_pois.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 90,
              child: SizedBox(
                height: 210,
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: _pois.length,
                  onPageChanged: (i) {
                    _currentIndex = i;
                    if (i >= 0 && i < _pois.length) {
                      final b = _pois[i];
                      _selectedLocation = b.latLng; // for routing
                    }
                  },
                  itemBuilder: (_, i) {
                    final b = _pois[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: GestureDetector(
                        onTap: () => _setDestination(b.latLng, title: b.name, addMarker: true),
                        onLongPress: widget.isAdmin ? () => _confirmDeleteFromCard(b) : null,
                        child: _PoiCard(poi: b),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Bottom actions (added CLEAR button)
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RoundIconButton(icon: Icons.directions_walk, onPressed: () => _showRoute(wheelchair: false)),
                _RoundIconButton(icon: Icons.accessible, onPressed: () => _showRoute(wheelchair: true)),
                _RoundIconButton(icon: Icons.my_location, onPressed: _animateToCurrent),
                _RoundIconButton(
                  icon: Icons.directions_bus,
                  onPressed: () {
                    if (_liveOn) {
                      _stopLiveBuses();
                      _toast('Live buses off');
                    } else {
                      _startLiveBuses();
                      _toast('Live buses on');
                    }
                  },
                ),
                _RoundIconButton( // NEW: clears red pin + route
                  icon: Icons.clear,
                  onPressed: _clearNavigation,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Simple card for carousel ---
class _PoiCard extends StatelessWidget {
  final CampusPoi poi;
  const _PoiCard({required this.poi});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = poi.isOpenNow ? theme.colorScheme.primary : theme.colorScheme.error;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Image.network(
              poi.imageUrl,
              height: 130,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(height: 130, color: Colors.grey.shade300),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(poi.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  poi.isOpenNow ? "Open · Closes ${poi.closesAt}" : "Closed · ${poi.closesAt}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: statusColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Circular button ---
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _RoundIconButton({required this.icon, required this.onPressed, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        padding: const EdgeInsets.all(16),
        elevation: 2,
      ),
      child: Icon(icon, size: 22),
    );
  }
}

// --- Route info model ---
class RouteInfo {
  final List<LatLng> points;
  final String distanceText;
  final String durationText;
  final int distanceMeters;
  final int durationSeconds;
  RouteInfo({
    required this.points,
    required this.distanceText,
    required this.durationText,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

double _deg2rad(double d) => d * pi / 180.0;
String _formatDistance(int meters) =>
    meters < 1000 ? '$meters m' : '${(meters / 1000).toStringAsFixed(1)} km';
String _formatDuration(int seconds) {
  if (seconds <= 0) return '';
  final m = (seconds / 60).round();
  if (m < 60) return '$m min';
  final h = m ~/ 60;
  final rm = m % 60;
  return rm == 0 ? '$h hr' : '$h hr $rm min';
}
