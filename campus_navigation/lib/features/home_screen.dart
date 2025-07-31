import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:campus_navigation/services/weather_service.dart';
import 'package:geolocator/geolocator.dart';
import 'notification_screen.dart';
import 'timetable_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userEmail;
  final VoidCallback onNavigateToMap;
  final Function(String, double?, double?) onSearch;

  const HomeScreen({
    super.key,
    required this.userEmail,
    required this.onNavigateToMap,
    required this.onSearch,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _weather = 'Fetching weather...';
  bool _weatherError = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];

  final String apiKey = "AIzaSyAsHYoxe5t5A8Zm8tPogYOfWFjAtyDionw";

  @override
  void initState() {
    super.initState();
    fetchWeather();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchWeather() async {
    try {
      await _checkLocationPermission();
      final weather = await WeatherService().getCurrentWeatherByLocation();
      setState(() {
        _weather = weather;
        _weatherError = false;
      });
    } catch (e) {
      setState(() {
        _weather = 'Unable to fetch weather';
        _weatherError = true;
      });
    }
  }

  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
  }

  Future<void> _getSuggestions(String input) async {
    if (input.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    const campusLat = 52.6219;
    const campusLng = -1.1244;
    const radius = 500;

    final url =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json"
        "?input=$input"
        "&location=$campusLat,$campusLng"
        "&radius=$radius"
        "&strictbounds=true"
        "&key=$apiKey";

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data['status'] == 'OK') {
      setState(() {
        _suggestions = List<Map<String, dynamic>>.from(
          data['predictions'].map((p) => {
            'description': p['description'],
            'place_id': p['place_id'],
          }),
        );
      });
    } else {
      setState(() => _suggestions = []);
    }
  }

  Future<void> _getPlaceDetails(String placeId, String name) async {
    final url =
        "https://maps.googleapis.com/maps/api/place/details/json"
        "?place_id=$placeId"
        "&fields=geometry"
        "&key=$apiKey";

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data['status'] == 'OK') {
      final loc = data['result']['geometry']['location'];
      final lat = loc['lat'];
      final lng = loc['lng'];

      widget.onSearch(name, lat, lng);
      setState(() => _suggestions = []);
    } else {
      widget.onSearch(name, null, null);
    }
  }

  Future<void> _launchUniversitySite() async {
    const url = 'https://le.ac.uk/';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String username = widget.userEmail.split('@').first;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: _launchUniversitySite,
              child: Image.asset(
                'assets/images/leicester_university_01.png',
                height: 150,
                errorBuilder: (context, error, stackTrace) {
                  return Text(
                    "University",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyMedium!.color,
                    ),
                  );
                },
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
              child: Stack(
                children: [
                  Icon(Icons.notifications_none,
                      size: 30, color: theme.iconTheme.color),
                  Positioned(
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                      child: const Text(
                        '1',
                        style: TextStyle(color: Colors.white, fontSize: 8),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Hi $username!',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: _getSuggestions,
                onSubmitted: (value) {
                  widget.onSearch(value, null, null);
                  setState(() => _suggestions = []);
                },
                decoration: InputDecoration(
                  hintText: 'Search for a building...',
                  prefixIcon: Icon(Icons.search, color: theme.iconTheme.color),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              if (_suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return ListTile(
                        title: Text(suggestion['description']),
                        onTap: () => _getPlaceDetails(
                          suggestion['place_id'],
                          suggestion['description'],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavButton(context, Icons.navigation, 'Navigate', widget.onNavigateToMap),
              _buildNavButton(context, Icons.schedule, 'Timetable', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TimetableScreen()));
              }),
              _buildNavButton(context, Icons.directions_bus, 'Buses', widget.onNavigateToMap),
            ],
          ),

          const SizedBox(height: 24),

          Text('Weather', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            color: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.wb_sunny, size: 40, color: theme.colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _weather,
                      style: TextStyle(
                        fontSize: 16,
                        color: _weatherError
                            ? theme.colorScheme.error
                            : theme.textTheme.bodyMedium!.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          Text("Today's Schedule", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildScheduleCard(context, 'Dissertation Class', 'KE LT2', '11:00 AM'),
          _buildScheduleCard(context, 'Generative Dev Lab', 'DW L011', '2:00 PM'),

          const SizedBox(height: 24),
          Text('Your Favorite Places', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFavPlace(context, Icons.local_library, 'Library'),
              _buildFavPlace(context, Icons.local_cafe, 'Cafe'),
              _buildFavPlace(context, Icons.fitness_center, 'Gym'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(BuildContext context, IconData icon, String label, VoidCallback onPressed) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPressed,
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            radius: 28,
            child: Icon(icon, color: theme.colorScheme.onPrimary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(BuildContext context, String title, String location, String time) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      color: theme.cardColor,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary,
          child: Icon(Icons.schedule, color: theme.colorScheme.onPrimary),
        ),
        title: Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            Icon(Icons.location_on, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(location),
            const SizedBox(width: 16),
            Text(time),
          ],
        ),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const TimetableScreen()));
        },
      ),
    );
  }

  Widget _buildFavPlace(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.all(14),
          child: Icon(icon, color: theme.colorScheme.primary, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
