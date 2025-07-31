import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  final String userEmail;
  const MainScreen({super.key, required this.userEmail});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  String _searchQuery = '';
  double? _searchLat;
  double? _searchLng;

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleSearch(String query, double? lat, double? lng) {
    setState(() {
      _searchQuery = query;
      _searchLat = lat;
      _searchLng = lng;
      _selectedIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        userEmail: widget.userEmail,
        onNavigateToMap: () => _onTabTapped(1),
        onSearch: _handleSearch,
      ),
      MapScreen(
        key: ValueKey("$_searchQuery-$_searchLat-$_searchLng"),
        searchQuery: _searchQuery,
        searchLat: _searchLat,
        searchLng: _searchLng,
      ),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        selectedItemColor: Colors.deepPurple,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
