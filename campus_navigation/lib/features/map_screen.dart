import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

class MapScreen extends StatefulWidget {
  final String searchQuery;
  final double? searchLat;
  final double? searchLng;

  const MapScreen({
    super.key,
    required this.searchQuery,
    this.searchLat,
    this.searchLng,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final PageController _pageCtrl = PageController(viewportFraction: 0.82);

  static const String apiKey = "AIzaSyAsHYoxe5t5A8Zm8tPogYOfWFjAtyDionw";
  static const LatLng campusCenter = LatLng(52.6219, -1.1244);

  static const String bodsSiriUrl =
      "https://data.bus-data.dft.gov.uk/api/v1/datafeed/18865/?api_key=1d4baf6fa7186850abd35eeff4b7f8af29a78fc1";

  static const String kTriggerLiveBuses = '__BUS_LIVE__';

  LatLng? _currentLocation;
  LatLng? _selectedLocation;
  int _currentIndex = 0;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  RouteInfo? _routeInfo;
  bool _isWheelchairRoute = false;

  Timer? _busPollTimer;
  BitmapDescriptor? _busIcon;
  bool _liveBusesActive = false;
  bool _didAutoFocusBuses = false;

  final List<_CampusBuilding> _featured = [
    _CampusBuilding(
      id: 'danielle-brown',
      name: 'Danielle Brown Sports Centre',
      latLng: const LatLng(52.6212, -1.1239),
      imageUrl: 'https://le.ac.uk/-/media/uol/images/sport/sports-centre.jpg',
      isOpenNow: false,
      closesAt: 'Opens 06:30',
      address: 'University Road, Leicester LE1 7RH',
      phone: '0116 252 3118',
      website: 'https://le.ac.uk/',
      hours: const {
        'Sunday': '08:00 - 19:30',
        'Monday': '06:30 - 22:00',
        'Tuesday': '06:30 - 22:00',
        'Wednesday': '06:30 - 22:00',
        'Thursday': '06:30 - 22:00',
        'Friday': '06:30 - 22:00',
        'Saturday': '08:00 - 19:30',
      },
    ),
    _CampusBuilding(
      id: 'sir-bob-burgess',
      name: 'Sir Bob Burgess Building',
      latLng: const LatLng(52.6208, -1.1272),
      imageUrl:
          'https://images.unsplash.com/photo-1541976076758-347942db1970?q=80&w=1200&auto=format&fit=crop',
      isOpenNow: true,
      closesAt: '6:00 PM',
      address: 'Leicester LE2 6BF',
    ),
    _CampusBuilding(
      id: 'charles-wilson',
      name: 'Charles Wilson Building',
      latLng: const LatLng(52.6222, -1.1234),
      imageUrl:
          'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?q=80&w=1200&auto=format&fit=crop',
      isOpenNow: false,
      closesAt: 'Opens 9:00 AM',
      address: 'University of Leicester, Leicester LE1 7RH',
      hours: const {
        'Sunday': 'Closed',
        'Monday': '09:00 - 18:00',
        'Tuesday': '09:00 - 18:00',
        'Wednesday': '09:00 - 18:00',
        'Thursday': '09:00 - 18:00',
        'Friday': '09:00 - 18:00',
        'Saturday': 'Closed',
      },
    ),
    _CampusBuilding(
      id: 'david-wilson-library',
      name: 'David Wilson Library',
      latLng: const LatLng(52.62184, -1.12541),
      imageUrl:
          'https://images.unsplash.com/photo-1507842217343-583bb7270b66?q=80&w=1200&auto=format&fit=crop',
      isOpenNow: true,
      closesAt: '12:00 AM',
      address: 'University Rd, Leicester LE1 7RH',
      website: 'https://le.ac.uk/library',
      hours: const {
        'Sunday': '08:00 - 00:00',
        'Monday': '08:00 - 00:00',
        'Tuesday': '08:00 - 00:00',
        'Wednesday': '08:00 - 00:00',
        'Thursday': '08:00 - 00:00',
        'Friday': '08:00 - 00:00',
        'Saturday': '08:00 - 00:00',
      },
    ),
    _CampusBuilding(
      id: 'engineering',
      name: 'Engineering Building',
      latLng: const LatLng(52.61990, -1.12410),
      imageUrl:
          'https://images.unsplash.com/photo-1541976076758-347942db1970?q=80&w=1200&auto=format&fit=crop',
      isOpenNow: false,
      closesAt: 'Closed',
      address: 'University Rd, Leicester LE1 7RH',
    ),
    _CampusBuilding(
      id: 'percy-gee',
      name: 'Percy Gee Building',
      latLng: const LatLng(52.62263, -1.12465),
      imageUrl:
          'https://images.unsplash.com/photo-1520975922284-9d8a25f5d20e?q=80&w=1200&auto=format&fit=crop',
      isOpenNow: true,
      closesAt: '5:00 PM',
      address: "Mayor's Walk, Leicester LE1 7RH",
    ),
    _CampusBuilding(
      id: 'ken-edwards',
      name: 'Ken Edwards Building',
      latLng: const LatLng(52.6215, -1.1250),
      imageUrl:
          'https://images.unsplash.com/photo-1507842217343-583bb7270b66?q=80&w=1200&auto=format&fit=crop',
      isOpenNow: true,
      closesAt: '6:00 PM',
      address: 'Ken Edwards Building, University Rd, Leicester LE1 7RH',
    ),
    _CampusBuilding(
      id: 'attenborough',
      name: 'Attenborough Building',
      latLng: const LatLng(52.6220, -1.1260),
      imageUrl:
          'https://images.unsplash.com/photo-1520975922284-9d8a25f5d20e?q=80&w=1200&auto=format&fit=crop',
      isOpenNow: true,
      closesAt: '6:00 PM',
      address: 'University of Leicester, University Rd, Leicester LE1 7RH',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadBusIcon();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Start live buses if triggered from Home
      if (widget.searchQuery == kTriggerLiveBuses) {
        _startLiveBuses();
        return;
      }

      if (widget.searchLat != null && widget.searchLng != null) {
        final coords = LatLng(widget.searchLat!, widget.searchLng!);
        await _selectDestination(
          coords,
          widget.searchQuery.isEmpty ? 'Selected location' : widget.searchQuery,
        );
        _highlightNearest(coords);
      } else if (widget.searchQuery.isNotEmpty) {
        final matched = _highlightByName(widget.searchQuery);
        if (!matched) {
          await _searchPlace(widget.searchQuery);
        }
      } else {
        _animateTo(campusCenter, zoom: 16);
      }
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _busPollTimer?.cancel();
    super.dispose();
  }

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

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _upsertMarker(
          Marker(
            markerId: const MarkerId("current_location"),
            position: _currentLocation!,
            infoWindow: const InfoWindow(title: "You are here"),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          ),
        );
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
    if (_currentLocation != null) {
      await _animateTo(_currentLocation!, zoom: 17);
    } else {
      await _initLocation();
      if (_currentLocation != null)
        await _animateTo(_currentLocation!, zoom: 17);
    }
  }

  void _upsertMarker(Marker marker) {
    _markers.removeWhere((m) => m.markerId == marker.markerId);
    _markers.add(marker);
  }

  Future<void> _selectDestination(LatLng coords, String title) async {
    setState(() {
      _selectedLocation = coords;
      _upsertMarker(
        Marker(
          markerId: const MarkerId('searched'),
          position: coords,
          infoWindow: InfoWindow(title: title),
        ),
      );
      _polylines.clear();
      _routeInfo = null;
    });
    await _animateTo(coords);
  }

  //
  bool _highlightByName(String q) {
    final query = q.toLowerCase().trim();
    final i = _featured.indexWhere((b) => b.name.toLowerCase().contains(query));
    if (i >= 0) {
      _jumpToCard(i);
      final b = _featured[i];
      _selectDestination(b.latLng, b.name);
      return true;
    } else {
      return false;
    }
  }

  void _highlightNearest(LatLng p) {
    int? minIdx;
    double best = double.infinity;
    for (int i = 0; i < _featured.length; i++) {
      final d = _haversine(p, _featured[i].latLng);
      if (d < best) {
        best = d;
        minIdx = i;
      }
    }
    if (minIdx != null) {
      _jumpToCard(minIdx);
    }
  }

  void _jumpToCard(int index) {
    _currentIndex = index;
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  double _haversine(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);
    final la1 = _deg2rad(a.latitude);
    final la2 = _deg2rad(b.latitude);
    final h =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(la1) * cos(la2) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * R * asin(sqrt(h));
  }

  double _deg2rad(double d) => d * pi / 180.0;

  Timer? _routeDebounce;
  Future<void> _showRoute({required bool wheelchair}) async {
    if (_selectedLocation == null) {
      _toast('Select a building first.');
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
        final route = await _getRouteWithStats(
          _currentLocation!,
          _selectedLocation!,
          wheelchair: wheelchair,
        );
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

  Future<RouteInfo> _getRouteWithStats(
    LatLng origin,
    LatLng dest, {
    required bool wheelchair,
  }) async {
    final params = {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${dest.latitude},${dest.longitude}',
      'mode': 'walking',
      'key': apiKey,
    };
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      params,
    );
    final resp = await http.get(url);
    if (resp.statusCode != 200) throw HttpException('HTTP ${resp.statusCode}');
    final data = json.decode(resp.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') {
      final em = (data['error_message'] as String?) ?? '';
      throw Exception(
        'Directions: ${data['status']} ${em.isNotEmpty ? '· $em' : ''}',
      );
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

  Future<void> _searchPlace(String query) async {
    if (query.trim().isEmpty) return;
    try {
      final url =
          Uri.https('maps.googleapis.com', '/maps/api/place/textsearch/json', {
            'query': query,
            'location': '${campusCenter.latitude},${campusCenter.longitude}',
            'radius': '2000',
            'key': apiKey,
          });
      final resp = await http.get(url);
      if (resp.statusCode != 200)
        throw HttpException('HTTP ${resp.statusCode}');
      final data = json.decode(resp.body) as Map<String, dynamic>;
      if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
        final result = (data['results'] as List).first as Map<String, dynamic>;
        final loc = result['geometry']['location'] as Map<String, dynamic>;
        final name = (result['name'] as String?) ?? query;
        final latLng = LatLng(
          (loc['lat'] as num).toDouble(),
          (loc['lng'] as num).toDouble(),
        );
        await _selectDestination(latLng, name);
        _highlightNearest(latLng);
      } else {
        _toast('No results for "$query" (${data['status']})');
      }
    } catch (_) {
      _toast('Search failed. Check network/API key.');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadBusIcon() async {
    try {
      _busIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/bus_marker.png', // optional; fallback below
      );
    } catch (_) {
      _busIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueOrange,
      );
    }
  }

  void _startLiveBuses() {
    if (_liveBusesActive) return;
    _liveBusesActive = true;
    _didAutoFocusBuses = false;

    _animateTo(campusCenter, zoom: 14);

    _busPollTimer?.cancel();
    _busPollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetchAndRenderSiri(),
    );
    _fetchAndRenderSiri();
  }

  void _stopLiveBuses() {
    _busPollTimer?.cancel();
    _busPollTimer = null;
    _liveBusesActive = false;
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

      final vehicleActivities = doc.descendants
          .whereType<xml.XmlElement>()
          .where((e) => e.name.local == 'VehicleActivity');

      final newBusMarkers = <Marker>{};
      LatLng? firstPos;

      for (final va in vehicleActivities) {
        final mvj = va.descendants.whereType<xml.XmlElement>().firstWhere(
          (e) => e.name.local == 'MonitoredVehicleJourney',
          orElse: () => xml.XmlElement(xml.XmlName('')),
        );
        if (mvj.name.local.isEmpty) continue;

        String id =
            _textOfFirst(mvj, 'VehicleRef') ??
            _textOfFirst(va, 'VehicleRef') ??
            'unknown';

        final loc = mvj.descendants.whereType<xml.XmlElement>().firstWhere(
          (e) => e.name.local == 'VehicleLocation',
          orElse: () => xml.XmlElement(xml.XmlName('')),
        );
        if (loc.name.local.isEmpty) continue;

        final latStr = _textOfFirst(loc, 'Latitude');
        final lngStr = _textOfFirst(loc, 'Longitude');
        if (latStr == null || lngStr == null) continue;

        final lat = double.tryParse(latStr);
        final lng = double.tryParse(lngStr);
        if (lat == null || lng == null) continue;

        final bearingStr = _textOfFirst(mvj, 'Bearing');
        final bearing = double.tryParse(bearingStr ?? '0') ?? 0.0;

        final pos = LatLng(lat, lng);
        firstPos ??= pos;

        final marker = Marker(
          markerId: MarkerId('bus_$id'),
          position: pos,
          rotation: bearing,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          icon:
              _busIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Centrebus (live)'),
        );

        newBusMarkers.add(marker);
      }

      if (!mounted) return;

      if (newBusMarkers.isEmpty) {
        _toast('No live Centrebus vehicles found right now. Try again soon.');
      } else {
        setState(() {
          _markers.removeWhere((m) => m.markerId.value.startsWith('bus_'));
          _markers.addAll(newBusMarkers);
        });

        // Auto-focus to where the buses actually are (only once per session toggle)
        if (!_didAutoFocusBuses && firstPos != null) {
          final c = await _controller.future;
          await c.animateCamera(CameraUpdate.newLatLngZoom(firstPos!, 13));
          _didAutoFocusBuses = true;
        }
      }
    } catch (e) {
      debugPrint('SIRI fetch error: $e');
      _toast('Could not parse live bus feed.');
    }
  }

  String? _textOfFirst(xml.XmlElement parent, String localName) {
    final n = parent.descendants.whereType<xml.XmlElement>().firstWhere(
      (e) => e.name.local == localName,
      orElse: () => xml.XmlElement(xml.XmlName('')),
    );
    if (n.name.local.isEmpty) return null;
    return n.text.trim().isEmpty ? null : n.text.trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: campusCenter,
              zoom: 16,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) {
              if (!_controller.isCompleted) {
                _controller.complete(controller);
              }
            },
          ),

          if (_routeInfo != null)
            Positioned(
              right: 16,
              bottom: 270,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(blurRadius: 6, color: Colors.black26),
                  ],
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
                        Icon(
                          _isWheelchairRoute ? Icons.accessible : Icons.timer,
                          size: 18,
                        ),
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

          SafeArea(
            bottom: true,
            minimum: const EdgeInsets.only(bottom: 190),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: PageView.builder(
                  controller: _pageCtrl,
                  onPageChanged: (i) {
                    _currentIndex = i;
                  },
                  itemCount: _featured.length,
                  itemBuilder: (context, i) {
                    final b = _featured[i];
                    final selected = i == _currentIndex;
                    return Padding(
                      padding: EdgeInsets.only(
                        left: i == 0 ? 16 : 8,
                        right: i == _featured.length - 1 ? 16 : 8,
                      ),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        scale: selected ? 1.0 : 0.96,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
                          child: FlippableBuildingCard(
                            building: b,
                            onCenter: () async {
                              _currentIndex = i;
                              await _selectDestination(b.latLng, b.name);
                              _pageCtrl.animateToPage(
                                i,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RoundIconButton(
                  icon: Icons.directions_walk,
                  onPressed: () => _showRoute(wheelchair: false),
                ),
                _RoundIconButton(
                  icon: Icons.accessible,
                  onPressed: () => _showRoute(wheelchair: true),
                ),
                _RoundIconButton(
                  icon: Icons.my_location,
                  onPressed: _animateToCurrent,
                ),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 88.0),
        child: FloatingActionButton.extended(
          onPressed: () {
            if (_liveBusesActive) {
              _stopLiveBuses();
              _toast('Live buses off');
            } else {
              _startLiveBuses();
              _toast('Live buses on');
            }
          },
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          icon: const Icon(Icons.directions_bus),
          label: Text(_liveBusesActive ? 'Live off' : 'Live buses'),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    super.key,
  });

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

class _CampusBuilding {
  final String id;
  final String name;
  final LatLng latLng;
  final String imageUrl;
  final bool isOpenNow;
  final String closesAt;
  final String? address;
  final String? phone;
  final String? website;
  final Map<String, String> hours;

  const _CampusBuilding({
    required this.id,
    required this.name,
    required this.latLng,
    required this.imageUrl,
    this.isOpenNow = true,
    this.closesAt = '',
    this.address,
    this.phone,
    this.website,
    this.hours = const {},
  });
}

class FlippableBuildingCard extends StatefulWidget {
  final _CampusBuilding building;
  final VoidCallback? onCenter;

  const FlippableBuildingCard({
    required this.building,
    this.onCenter,
    super.key,
  });

  @override
  State<FlippableBuildingCard> createState() => _FlippableBuildingCardState();
}

class _FlippableBuildingCardState extends State<FlippableBuildingCard> {
  bool _showBack = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _showBack = !_showBack);
        widget.onCenter?.call();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final rotate = Tween(begin: pi, end: 0.0).animate(animation);
          return AnimatedBuilder(
            animation: rotate,
            child: child,
            builder: (context, child) {
              final isUnder = (child!.key != ValueKey(_showBack));
              var tilt = (animation.value - 0.5).abs() - 0.5;
              tilt *= isUnder ? -0.003 : 0.003;
              return Transform(
                transform: Matrix4.rotationY(rotate.value)
                  ..setEntry(3, 0, tilt),
                alignment: Alignment.center,
                child: child,
              );
            },
          );
        },
        child: _showBack
            ? _BackCard(building: widget.building, key: const ValueKey(true))
            : _FrontCard(building: widget.building, key: const ValueKey(false)),
      ),
    );
  }
}

class _FrontCard extends StatelessWidget {
  final _CampusBuilding building;
  const _FrontCard({required this.building, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = building.isOpenNow
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

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
              building.imageUrl,
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
                Text(
                  building.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  building.isOpenNow
                      ? "Open · Closes ${building.closesAt}"
                      : "Closed · ${building.closesAt}",
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

class _BackCard extends StatelessWidget {
  final _CampusBuilding building;
  const _BackCard({required this.building, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = TextStyle(color: Colors.grey.shade700);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            building.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (building.address != null) Text(building.address!),
          if (building.phone != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text("📞 ${building.phone!}", style: dim),
            ),
          if (building.website != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text("🌐 ${building.website!}", style: dim),
            ),
          const SizedBox(height: 10),
          if (building.hours.isNotEmpty) ...[
            const Text(
              "Opening Hours:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: building.hours.entries
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: Text("${e.key}: ${e.value}"),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }
}

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

String _formatDistance(int meters) {
  if (meters < 1000) return '$meters m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

String _formatDuration(int seconds) {
  if (seconds <= 0) return '';
  final m = (seconds / 60).round();
  if (m < 60) return '$m min';
  final h = m ~/ 60;
  final rm = m % 60;
  if (rm == 0) return '$h hr';
  return '$h hr $rm min';
}
