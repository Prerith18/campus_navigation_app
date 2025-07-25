import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:campus_navigation/services/weather_service.dart';
import 'package:geolocator/geolocator.dart';
import 'notification_screen.dart';
import 'timetable_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userEmail;
  final VoidCallback onNavigateToMap;
  final Function(String) onSearch;

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

  Future<void> _launchUniversitySite() async {
    const url = 'https://le.ac.uk/';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String username = widget.userEmail.split('@').first;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
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
                  return const Text(
                    "University",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  const Icon(Icons.notifications_none, size: 30),
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
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _searchController,
            onSubmitted: widget.onSearch,
            decoration: InputDecoration(
              hintText: 'Search for a building...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavButton(Icons.navigation, 'Navigate', widget.onNavigateToMap),
              _buildNavButton(Icons.schedule, 'Timetable', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TimetableScreen()));
              }),
              _buildNavButton(Icons.directions_bus, 'Buses', widget.onNavigateToMap),
            ],
          ),

          const SizedBox(height: 24),

          const Text('Weather', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.wb_sunny, size: 40, color: Colors.deepPurple),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _weather,
                      style: TextStyle(
                        fontSize: 16,
                        color: _weatherError ? Colors.red : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Text("Today's Schedule", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          _buildScheduleCard('Dissertation Class', 'KE LT2', '11:00 AM'),
          _buildScheduleCard('Generative Dev Lab', 'DW L011', '2:00 PM'),

          const SizedBox(height: 24),
          const Text('Your Favorite Places', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFavPlace(Icons.local_library, 'Library'),
              _buildFavPlace(Icons.local_cafe, 'Cafe'),
              _buildFavPlace(Icons.fitness_center, 'Gym'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: Colors.deepPurple,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(String title, String location, String time) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const TimetableScreen()));
        },
        leading: const CircleAvatar(
          backgroundColor: Colors.deepPurple,
          child: Icon(Icons.schedule, color: Colors.white),
        ),
        title: Text(title),
        subtitle: Row(
          children: [
            const Icon(Icons.location_on, size: 16),
            const SizedBox(width: 4),
            Text(location),
            const SizedBox(width: 16),
            Text(time),
          ],
        ),
      ),
    );
  }

  Widget _buildFavPlace(IconData icon, String label) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.deepPurple),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }
}
