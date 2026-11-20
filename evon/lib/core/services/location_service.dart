import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/api_constants.dart';
import 'api_service.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String area;
  final String city;

  LocationResult({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    this.area = '',
    this.city = 'Bengaluru',
  });

  factory LocationResult.fromJson(Map<String, dynamic> json) {
    return LocationResult(
      latitude: (json['lat'] as num?)?.toDouble() ?? 12.9716,
      longitude: (json['lng'] as num?)?.toDouble() ?? 77.5946,
      formattedAddress: json['formattedAddress'] ?? 'Bengaluru, Karnataka, India',
      area: json['area'] ?? '',
      city: json['city'] ?? 'Bengaluru',
    );
  }
}

class LocationSuggestion {
  final String name;
  final String formattedAddress;
  final double lat;
  final double lng;
  final String placeId;

  LocationSuggestion({
    required this.name,
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    this.placeId = '',
  });

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      name: json['name'] ?? '',
      formattedAddress: json['formattedAddress'] ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 12.9716,
      lng: (json['lng'] as num?)?.toDouble() ?? 77.5946,
      placeId: json['placeId'] ?? '',
    );
  }
}

class LocationService {
  final Dio _dio = ApiService().dio;

  static const double defaultLat = 12.9716;
  static const double defaultLng = 77.5946;

  /// Fetches device GPS position using Geolocator
  Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      return null;
    }
  }

  /// Reverse geocode GPS coords to real street address using Google Maps API
  Future<LocationResult?> reverseGeocode(double lat, double lng) async {
    try {
      final res = await _dio.get(
        ApiConstants.locationReverse,
        queryParameters: {'lat': lat, 'lng': lng},
      );
      if (res.statusCode == 200 && res.data['success'] == true) {
        return LocationResult.fromJson(res.data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Geocode text address into exact coordinates using Google Maps API
  Future<LocationResult?> geocodeAddress(String address) async {
    try {
      final res = await _dio.get(
        ApiConstants.locationGeocode,
        queryParameters: {'address': address},
      );
      if (res.statusCode == 200 && res.data['success'] == true) {
        return LocationResult.fromJson(res.data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Search places, neighborhoods, and areas with Google Maps API
  Future<List<LocationSuggestion>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final res = await _dio.get(
        ApiConstants.locationSearch,
        queryParameters: {'query': query},
      );
      if (res.statusCode == 200 && res.data['success'] == true) {
        final List list = res.data['locations'] ?? [];
        return list.map((item) => LocationSuggestion.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
