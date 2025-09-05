import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';

/// Root shell with three tabs (Home, Map, Profile) and shared search handoff.
class MainScreen extends StatefulWidget {
  final String userEmail;
  const MainScreen({super.key, required this.userEmail});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

/// Holds current tab and cross-tab search state for the Map view.
class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  String _searchQuery = '';
  double? _searchLat;
  double? _searchLng;

  /// Switches the selected bottom tab.
  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  /// Receives a search from Home and forwards it to the Map tab.
  void _handleSearch(String query, double? lat, double? lng) {
    setState(() {
      _searchQuery = query;
      _searchLat = lat;
      _searchLng = lng;
      _selectedIndex = 1; // jump to Map tab
    });
  }

  /// Builds the tab scaffolding and bottom navigation bar.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final screens = <Widget>[
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
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onTabTapped,
        height: 64,
        elevation: 2,
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
