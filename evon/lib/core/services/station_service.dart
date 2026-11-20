import 'package:dio/dio.dart';
import '../../models/station_model.dart';
import '../../models/slot_model.dart';
import '../constants/api_constants.dart';
import 'api_service.dart';

class StationService {
  final Dio _dio = ApiService().dio;

  Future<List<StationModel>> getAllStations() async {
    try {
      final res = await _dio.get(ApiConstants.stations);
      if (res.statusCode == 200 && res.data['success'] == true) {
        final List list = res.data['stations'] ?? [];
        return list.map((item) => StationModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<StationModel>> getStations() => getAllStations();

  Future<List<StationModel>> getNearbyStations({
    double? lat,
    double? lng,
    String? location,
    double maxDistanceKm = 50.0,
  }) async {
    try {
      final Map<String, dynamic> params = {'maxDistanceKm': maxDistanceKm};
      if (lat != null && lng != null) {
        params['lat'] = lat;
        params['lng'] = lng;
      }
      if (location != null && location.isNotEmpty) {
        params['location'] = location;
      }

      final res = await _dio.get(
        ApiConstants.nearbyStations,
        queryParameters: params,
      );
      if (res.statusCode == 200 && res.data['success'] == true) {
        final List list = res.data['stations'] ?? [];
        return list.map((item) => StationModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<SlotModel>> getStationSlots({
    required String stationId,
    required String dateStr,
  }) async {
    try {
      final res = await _dio.get(
        ApiConstants.stationSlots(stationId),
        queryParameters: {'date': dateStr},
      );
      if (res.statusCode == 200 && res.data['success'] == true) {
        final List list = res.data['slots'] ?? [];
        return list.map((item) => SlotModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getRouteRecommendations({
    required String origin,
    required String destination,
    double? currentSoc,
    double? batteryCapacity,
  }) async {
    try {
      final query = <String, dynamic>{
        'origin': origin,
        'destination': destination,
      };
      if (currentSoc != null) query['currentSoc'] = currentSoc;
      if (batteryCapacity != null) query['batteryCapacity'] = batteryCapacity;

      final res = await _dio.get(
        ApiConstants.routeRecommendations,
        queryParameters: query,
      );
      if (res.statusCode == 200 && res.data['success'] == true) {
        return res.data;
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  // --- Admin Methods ---

  Future<List<dynamic>> getAllBookings({String? stationId, String? status}) async {
    try {
      final query = <String, dynamic>{};
      if (stationId != null && stationId.isNotEmpty) query['stationId'] = stationId;
      if (status != null && status.isNotEmpty) query['status'] = status;

      final res = await _dio.get(ApiConstants.allBookings, queryParameters: query);
      if (res.statusCode == 200 && res.data['success'] == true) {
        return res.data['bookings'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> updateBookingStatus(String bookingId, String status) async {
    try {
      final res = await _dio.put(
        ApiConstants.updateBookingStatus(bookingId),
        data: {'status': status},
      );
      return res.statusCode == 200 && res.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateSlotStatus(String slotId, String status) async {
    try {
      final res = await _dio.put(
        ApiConstants.updateSlotStatus(slotId),
        data: {'status': status},
      );
      return res.statusCode == 200 && res.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getStationAdmins() async {
    try {
      final res = await _dio.get(ApiConstants.stationAdmins);
      if (res.statusCode == 200 && res.data['success'] == true) {
        return res.data['admins'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<({bool success, String message, dynamic admin})> createStationAdmin({
    required String name,
    required String email,
    required String password,
    String phone = '',
    required String assignedStation,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.stationAdmins,
        data: {
          'name': name,
          'email': email,
          'password': password,
          'phone': phone,
          'assignedStation': assignedStation,
        },
      );
      if (res.statusCode == 201 && res.data['success'] == true) {
        return (
          success: true,
          message: res.data['message']?.toString() ?? 'Station admin created successfully.',
          admin: res.data['admin'],
        );
      }
      return (
        success: false,
        message: res.data?['message']?.toString() ?? 'Failed to create station admin.',
        admin: null,
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message']?.toString() ??
          'Failed to create station admin. (${e.response?.statusCode ?? "Error"})';
      return (success: false, message: msg, admin: null);
    } catch (e) {
      return (success: false, message: 'An unexpected error occurred: $e', admin: null);
    }
  }

  Future<bool> deleteStationAdmin(String adminId) async {
    try {
      final res = await _dio.delete('${ApiConstants.stationAdmins}/$adminId');
      return res.statusCode == 200 && res.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getStationDemand(String stationId) async {
    try {
      final res = await _dio.get(ApiConstants.stationDemand(stationId));
      if (res.statusCode == 200 && res.data['success'] == true) {
        return res.data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStationLoadForecast({
    String? stationId,
    int horizonHours = 24,
  }) async {
    try {
      final query = <String, dynamic>{'horizonHours': horizonHours};
      if (stationId != null && stationId.isNotEmpty) query['stationId'] = stationId;

      final res = await _dio.get(
        ApiConstants.loadForecast,
        queryParameters: query,
      );
      if (res.statusCode == 200 && res.data['success'] == true) {
        return res.data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStationAnalytics(String stationId) async {
    try {
      final res = await _dio.get(ApiConstants.stationAnalytics(stationId));
      if (res.statusCode == 200 && res.data['success'] == true) {
        return res.data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<StationModel?> getIotHubStatus() async {
    try {
      final res = await _dio.get(ApiConstants.iotStatus);
      if (res.statusCode == 200 && res.data['success'] == true) {
        return StationModel.fromJson(res.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateIotBay({required int bay, required String status}) async {
    try {
      final res = await _dio.post(
        ApiConstants.iotBayStatus,
        data: {'bay': bay, 'status': status},
      );
      return res.statusCode == 200 && res.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> resetIotBays() async {
    try {
      final res = await _dio.post(ApiConstants.iotReset);
      return res.statusCode == 200 && res.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> disconnectIot() async {
    try {
      final res = await _dio.post(ApiConstants.iotDisconnect);
      return res.statusCode == 200 && res.data['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
