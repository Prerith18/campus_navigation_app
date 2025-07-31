import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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
  static const String apiKey = "YOUR_API_KEY";
  static const LatLng campusCenter = LatLng(52.6219, -1.1244);

  LatLng? _selectedLocation;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    if (widget.searchLat != null && widget.searchLng != null) {
      _setMarker(LatLng(widget.searchLat!, widget.searchLng!), widget.searchQuery);
    } else if (widget.searchQuery.isNotEmpty) {
      _searchPlace(widget.searchQuery);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.future.then((controller) {
      _applyMapStyle(controller); 
    });
  }

  Future<void> _applyMapStyle(GoogleMapController controller) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      controller.setMapStyle('''
      [
        {"elementType": "geometry","stylers": [{"color": "#212121"}]},
        {"elementType": "labels.text.fill","stylers": [{"color": "#757575"}]},
        {"elementType": "labels.text.stroke","stylers": [{"color": "#212121"}]},
        {"featureType": "road","elementType": "geometry","stylers": [{"color": "#383838"}]}
      ]
      ''');
    } else {
      controller.setMapStyle(null);
    }
  }

  Future<void> _setMarker(LatLng coords, String title) async {
    setState(() {
      _selectedLocation = coords;
      _markers = {
        Marker(
          markerId: const MarkerId("searched"),
          position: coords,
          infoWindow: InfoWindow(title: title),
        ),
      };
    });
    _moveToLocation(coords);
  }

  Future<void> _searchPlace(String query) async {
    final url =
        "https://maps.googleapis.com/maps/api/place/textsearch/json?query=$query&location=${campusCenter.latitude},${campusCenter.longitude}&radius=2000&key=$apiKey";

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data['status'] == 'OK') {
      final location = data['results'][0]['geometry']['location'];
      _setMarker(LatLng(location['lat'], location['lng']), query);
    }
  }

  Future<void> _moveToLocation(LatLng latLng) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(latLng, 17));
  }

  Future<void> _goToCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    LatLng currentLatLng = LatLng(position.latitude, position.longitude);

    setState(() {
      _markers.add(
        Marker(
          markerId: const MarkerId("current_location"),
          position: currentLatLng,
          infoWindow: const InfoWindow(title: "You are here"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    });

    _moveToLocation(currentLatLng);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: campusCenter, zoom: 16),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _markers,
            onMapCreated: (controller) {
              _controller.complete(controller);
              _applyMapStyle(controller);
            },
          ),

          Positioned(
            bottom: 120,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.deepPurple,
              onPressed: _goToCurrentLocation,
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
