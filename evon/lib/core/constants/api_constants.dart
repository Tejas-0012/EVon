class ApiConstants {
  // If running on Android Emulator: use 10.0.2.2
  // If running on iOS Simulator or Web: use localhost
  // If running on physical mobile device: replace with your local machine IP (e.g. 192.168.1.X)
  static const String baseUrl = 'http://10.139.74.187:5000/api';

  // Auth endpoints
  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';
  static const String me = '$baseUrl/auth/me';
  static const String profile = '$baseUrl/auth/profile';

  // Station endpoints
  static const String stations = '$baseUrl/stations';
  static const String nearbyStations = '$baseUrl/stations/nearby';
  static String stationSlots(String stationId) =>
      '$baseUrl/stations/$stationId/slots';

  // Booking endpoints
  static const String quote = '$baseUrl/bookings/quote';
  static const String bookings = '$baseUrl/bookings';
  static const String myBookings = '$baseUrl/bookings/my';
  static const String allBookings = '$baseUrl/bookings';
  static String cancelBooking(String id) => '$baseUrl/bookings/$id/cancel';
  static String updateBookingStatus(String id) =>
      '$baseUrl/bookings/$id/status';

  // Slot endpoints
  static String updateSlotStatus(String slotId) => '$baseUrl/slots/$slotId';

  // Payment endpoints
  static const String payments = '$baseUrl/payments';

  // Recommendation endpoints
  static const String routeRecommendations = '$baseUrl/recommendations/route';

  // ML & Analytics endpoints
  static const String mlStatus = '$baseUrl/ml/status';
  static const String loadForecast = '$baseUrl/ml/load/forecast';
  static String stationDemand(String stationId) =>
      '$baseUrl/ml/demand/station/$stationId';
  static const String adminOverview = '$baseUrl/analytics/overview';
  static String stationAnalytics(String stationId) =>
      '$baseUrl/analytics/station/$stationId';

  // Admin Management endpoints
  static const String stationAdmins = '$baseUrl/auth/station-admins';
  static const String seedAdmins = '$baseUrl/auth/seed-admins';

  // IoT Hardware Hub endpoints (ESP32)
  static const String iotStatus = '$baseUrl/iot/status';
  static const String iotBayStatus = '$baseUrl/iot/bay-status';
  static const String iotReset = '$baseUrl/iot/reset';
  static const String iotDisconnect = '$baseUrl/iot/disconnect';

  // Google Maps Location & Geocoding endpoints
  static const String locationGeocode = '$baseUrl/locations/geocode';
  static const String locationReverse = '$baseUrl/locations/reverse';
  static const String locationSearch = '$baseUrl/locations/search';
}
