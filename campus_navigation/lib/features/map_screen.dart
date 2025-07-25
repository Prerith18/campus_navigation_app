import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  final String searchQuery;
  const MapScreen({super.key, required this.searchQuery});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Map<String, LatLng> _locations = {
    'library': LatLng(52.6369, -1.1398),
    'cafe': LatLng(52.6375, -1.1401),
    'gym': LatLng(52.6360, -1.1375),
    'student union': LatLng(52.6362, -1.1380),
    'percy gee building': LatLng(52.6356, -1.1389),
  };

  LatLng? _selectedLocation;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    final query = widget.searchQuery.toLowerCase();
    if (_locations.containsKey(query)) {
      _selectedLocation = _locations[query];
      _markers = {
        Marker(
          markerId: const MarkerId("selected"),
          position: _selectedLocation!,
          infoWindow: InfoWindow(title: widget.searchQuery),
        ),
      };
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _moveToLocation(_selectedLocation!);
      });
    }
  }

  Future<void> _moveToLocation(LatLng latLng) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(latLng, 17),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation ?? const LatLng(52.6369, -1.1398),
              zoom: 16,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
          ),

          Positioned(
            bottom: 160,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.deepPurple,
              onPressed: () {
                if (_selectedLocation != null) {
                  _moveToLocation(_selectedLocation!);
                }
              },
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),

          if (_selectedLocation != null)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/percee_gee.jpeg',
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Percy Gee Building",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: const [
                        Text("Open", style: TextStyle(color: Colors.green)),
                        SizedBox(width: 10),
                        Text("• Closes 5:00 PM", style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
