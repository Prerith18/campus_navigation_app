import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

// Small helper that fetches current weather using device location + OpenWeather.
class WeatherService {
  final String _apiKey = '2e3c375c5d6363104850fcf69456e5e0';

  // Returns a short "City: temp°C, description" string for the user's current spot.
  Future<String> getCurrentWeatherByLocation() async {
    try {

      // Ask for location permission before attempting to read position.
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
          return 'Location permission denied';
        }
      }

      // Read a fresh, high-accuracy GPS fix.
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      // Build the OpenWeather request and call the API (metric units).
      final url = 'https://api.openweathermap.org/data/2.5/weather'
          '?lat=${position.latitude}&lon=${position.longitude}&appid=$_apiKey&units=metric';

      final response = await http.get(Uri.parse(url));

      // Parse a successful response, otherwise fall back to a friendly message.
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final temp = data['main']['temp'];
        final description = data['weather'][0]['description'];
        final city = data['name'];
        return '$city: $temp°C, $description';
      } else {
        return 'Weather not found';
      }
    } catch (e) {
      // Any network/permission issues end up here as a readable string.
      return 'Error: ${e.toString()}';
    }
  }
}
