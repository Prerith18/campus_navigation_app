import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

  class WeatherService {
  final String _apiKey = '2e3c375c5d6363104850fcf69456e5e0';

  Future<String> getCurrentWeatherByLocation() async {
  try {

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
  permission = await Geolocator.requestPermission();
  if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
  return 'Location permission denied';
  }
  }

  Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

  final url = 'https://api.openweathermap.org/data/2.5/weather'
  '?lat=${position.latitude}&lon=${position.longitude}&appid=$_apiKey&units=metric';

  final response = await http.get(Uri.parse(url));
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
  return 'Error: ${e.toString()}';
  }
  }
  }
