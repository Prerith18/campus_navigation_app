import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:campus_navigation/services/weather_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_screen.dart';
import 'user_timetable_screen.dart';

import 'package:intl/intl.dart';
import 'package:campus_navigation/services/timetable_repository.dart';
import 'package:campus_navigation/models/timetable_session.dart';

/// Home screen: greeting, building search (text/voice), quick actions,
/// weather, today's classes, favourites, and a notifications bell.
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

  // Google Places API key (consider securing for production).
  final String apiKey = "AIzaSyAsHYoxe5t5A8Zm8tPogYOfWFjAtyDionw";

  late stt.SpeechToText _speech;
  bool _isListening = false;

  /// Initialize weather load and speech engine.
  @override
  void initState() {
    super.initState();
    fetchWeather();
    _speech = stt.SpeechToText();
  }

  /// Dispose controllers to avoid leaks.
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Fetch current weather (after checking location permission) and update UI.
  Future<void> fetchWeather() async {
    try {
      await _checkLocationPermission();
      final weather = await WeatherService().getCurrentWeatherByLocation();
      if (!mounted) return;
      setState(() {
        _weather = weather;
        _weatherError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weather = 'Unable to fetch weather';
        _weatherError = true;
      });
    }
  }

  /// Request location permission if needed.
  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }
  }

  /// Toggle voice input for search; auto-searches on final recognition.
  Future<void> _toggleListening() async {
    if (!_isListening) {
      final available = await _speech.initialize(
        onStatus: (status) => debugPrint('Speech status: $status'),
        onError: (error) => debugPrint('Speech error: $error'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) async {
            if (result.finalResult) {
              final spokenText = result.recognizedWords;
              _searchController.text = spokenText;
              await _getSuggestions(spokenText);
              await _resolveAndNavigate();
              _stopListening();
            }
          },
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
    } else {
      _stopListening();
    }
  }

  /// Stop active voice capture.
  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  /// Entry point for the search button.
  Future<void> _onSearchPressed() async {
    await _getSuggestions(_searchController.text);
    await _resolveAndNavigate();
  }

  /// Decide whether to navigate using a resolved place or raw query.
  Future<void> _resolveAndNavigate() async {
    FocusScope.of(context).unfocus();
    await SystemChannels.textInput.invokeMethod('TextInput.hide');

    if (_suggestions.isNotEmpty) {
      final first = _suggestions.first;
      await _getPlaceDetails(first['place_id'], first['description']);
    } else {
      widget.onSearch(_searchController.text, null, null);
      setState(() => _suggestions = []);
      widget.onNavigateToMap();
    }
  }

  /// Fetch autocomplete suggestions near campus for the given input.
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

  /// Resolve a place to lat/lng (when possible) and navigate to the map.
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
      final double lat = (loc['lat'] as num).toDouble();
      final double lng = (loc['lng'] as num).toDouble();

      widget.onSearch(name, lat, lng);
    } else {
      widget.onSearch(name, null, null);
    }

    setState(() => _suggestions = []);
    widget.onNavigateToMap();
  }

  /// Opens the university website externally.
  Future<void> _launchUniversitySite() async {
    const url = 'https://le.ac.uk/';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Builds the home scaffold: header, search, quick actions, weather, schedule, favourites.
  @override
  Widget build(BuildContext context) {
    final emailFirst = widget.userEmail.split('@').first;
    final username = emailFirst.isEmpty
        ? 'there'
        : '${emailFirst[0].toUpperCase()}${emailFirst.substring(1)}';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor:
        theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: _launchUniversitySite,
              child: Image.asset(
                'assets/images/leicester_university_01.png',
                height: 150,
                errorBuilder: (_, __, ___) => Text(
                  "University",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyMedium!.color,
                  ),
                ),
              ),
            ),
            _NotificationBell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Hi $username!',
            style:
            theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Search bar with typeahead suggestions and voice toggle.
          Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: _getSuggestions,
                onSubmitted: (value) async {
                  await _getSuggestions(value);
                  await _resolveAndNavigate();
                },
                decoration: InputDecoration(
                  hintText: 'Search for a building...',
                  prefixIcon: IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic_off : Icons.mic,
                      color: _isListening ? Colors.red : theme.iconTheme.color,
                    ),
                    onPressed: _toggleListening,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search, color: theme.iconTheme.color),
                    onPressed: _onSearchPressed,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                textInputAction: TextInputAction.search,
              ),
              if (_suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4)
                    ],
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        return ListTile(
                          title: Text(suggestion['description']),
                          onTap: () async {
                            FocusScope.of(context).unfocus();
                            await SystemChannels.textInput
                                .invokeMethod('TextInput.hide');
                            await _getPlaceDetails(
                              suggestion['place_id'],
                              suggestion['description'],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),

          // Quick action buttons: navigate, timetable, buses.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavButton(context, Icons.navigation, 'Navigate', () async {
                FocusScope.of(context).unfocus();
                await SystemChannels.textInput.invokeMethod('TextInput.hide');
                widget.onNavigateToMap();
              }),
              _buildNavButton(context, Icons.schedule, 'Timetable', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TimetableScreen()),
                );
              }),
              _buildNavButton(context, Icons.directions_bus, 'Buses', () async {
                FocusScope.of(context).unfocus();
                await SystemChannels.textInput.invokeMethod('TextInput.hide');
                widget.onNavigateToMap();
              }),
            ],
          ),

          const SizedBox(height: 24),

          // Weather summary card.
          Text('Weather',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
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

          // Live "Today's Schedule" from the published timetable.
          Text("Today's Schedule",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _TodayScheduleCard(
            onGoToClass: (session) {
              widget.onSearch(session.locationName, session.lat, session.lng);
              widget.onNavigateToMap();
            },
          ),

          const SizedBox(height: 24),

          // Favourite places pulled from Firestore (up to three).
          Text('Your Favorite Places',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          Builder(builder: (context) {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid == null) {
              return Text('Sign in to use favourites.',
                  style: theme.textTheme.bodySmall);
            }
            final stream = FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('savedRoutes')
                .orderBy('order')
                .limit(3)
                .snapshots();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Text('Set up favourites in Profile → Saved Routes.',
                      style: theme.textTheme.bodySmall);
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final d in docs)
                      _FavChip(
                        label:
                        (d['label'] ?? d['placeName'] ?? 'Favourite') as String,
                        onTap: () {
                          final name = (d['placeName'] ?? d['label']) as String;
                          final lat = (d['lat'] as num?)?.toDouble();
                          final lng = (d['lng'] as num?)?.toDouble();
                          widget.onSearch(name, lat, lng);
                          widget.onNavigateToMap();
                        },
                      ),
                  ],
                );
              },
            );
          }),
        ],
      ),
    );
  }

  /// Small circular nav button used in the quick actions row.
  Widget _buildNavButton(
      BuildContext context, IconData icon, String label, VoidCallback onPressed) {
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
          Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Notification bell that shows an unread count badge from Firestore.
class _NotificationBell extends StatelessWidget {
  final VoidCallback onTap;
  const _NotificationBell({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return IconButton(
        icon: const Icon(Icons.notifications_none),
        onPressed: onTap,
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('userNotifications')
        .doc(uid)
        .collection('items')
        .where('read', isEqualTo: false)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final unread = snap.data?.size ?? 0;
        return InkWell(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.notifications_none,
                size: 30,
                color: Theme.of(context).iconTheme.color,
              ),
              if (unread > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints:
                    const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Card that streams today’s published sessions and offers "Go to class".
class _TodayScheduleCard extends StatelessWidget {
  final void Function(TimetableSession session) onGoToClass;
  const _TodayScheduleCard({required this.onGoToClass});

  @override
  Widget build(BuildContext context) {
    final repo = TimetableRepository.instance;
    final localNow = DateTime.now();
    final df = DateFormat('HH:mm');

    return Card(
      elevation: 2,
      child: StreamBuilder<List<TimetableSession>>(
        stream: repo.streamTodayFromPublished(localNow: localNow),
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: ${snap.error}'),
            );
          }
          final today = snap.data ?? [];

          if (today.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No classes today.'),
            );
          }

          return Column(
            children: [
              for (final s in today) ...[
                ListTile(
                  leading: const Icon(Icons.event_available),
                  title: Text(s.title),
                  subtitle: Text(
                    '${df.format(s.startTime.toDate().toLocal())}'
                        '–${df.format(s.endTime.toDate().toLocal())}'
                        ' • ${s.locationName}${s.room != null ? ' • ${s.room}' : ''}',
                  ),
                  trailing: TextButton(
                    onPressed: () => onGoToClass(s),
                    child: const Text('Go to class'),
                  ),
                ),
                const Divider(height: 1),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Rounded favourite shortcut used in the favourites row.
class _FavChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FavChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.all(14),
            child: Icon(Icons.star, color: theme.colorScheme.primary, size: 28),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
