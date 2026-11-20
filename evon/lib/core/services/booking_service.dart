import 'dart:convert';
import 'package:dio/dio.dart';

import '../../models/booking_model.dart';
import '../../models/quote_model.dart';
import '../constants/api_constants.dart';
import 'api_service.dart';

class BookingService {
  final Dio _dio = ApiService().dio;

  Future<QuoteModel?> getQuote({
    required String stationId,
    required double batteryCapacity,
    required double currentSoc,
    required double desiredSoc,
    String? slotDate,
    String? slotTime,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.quote,
        data: {
          'stationId': stationId,
          'batteryCapacity': batteryCapacity,
          'currentSoc': currentSoc,
          'desiredSoc': desiredSoc,
          'slotDate': slotDate,
          'slotTime': slotTime,
        },
      );
      if (res.statusCode == 200 && res.data['success'] == true) {
        return QuoteModel.fromJson(res.data['quote']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<BookingModel?> createBooking({
    required String stationId,
    required String slotId,
    required String slotDate,
    required String slotTime,
    String vehicleType = 'Electric Car',
    required double batteryCapacity,
    required double currentSoc,
    required double desiredSoc,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.bookings,
        data: {
          'stationId': stationId,
          'slotId': slotId,
          'slotDate': slotDate,
          'slotTime': slotTime,
          'vehicleType': vehicleType,
          'batteryCapacity': batteryCapacity,
          'currentSoc': currentSoc,
          'desiredSoc': desiredSoc,
        },
      );
      if (res.statusCode == 201 && res.data['success'] == true) {
        return BookingModel.fromJson(res.data['booking']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<BookingModel>> getMyBookings() async {
    try {
      final res = await _dio.get(ApiConstants.myBookings);
      if (res.statusCode == 200 && res.data['success'] == true) {
        final List list = res.data['bookings'] ?? [];
        return list.map((item) => BookingModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<({bool success, String message})> cancelBooking(String bookingId) async {
    try {
      final res = await _dio.put(ApiConstants.cancelBooking(bookingId));
      if (res.statusCode == 200 && res.data != null && res.data['success'] == true) {
        return (
          success: true,
          message: res.data['message']?.toString() ?? 'Booking cancelled successfully.',
        );
      }
      return (
        success: false,
        message: res.data?['message']?.toString() ?? 'Failed to cancel booking.',
      );
    } on DioException catch (e) {
      String msg = 'Failed to cancel booking.';
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        msg = data['message'].toString();
      } else if (data is String) {
        try {
          final parsed = jsonDecode(data);
          if (parsed is Map && parsed['message'] != null) {
            msg = parsed['message'].toString();
          }
        } catch (_) {}
      } else if (e.response?.statusCode != null) {
        msg = 'Failed to cancel booking (${e.response?.statusCode}).';
      }
      return (success: false, message: msg);
    } catch (e) {
      return (success: false, message: 'An unexpected error occurred: $e');
    }
  }

  Future<({bool success, String message})> payBooking({
    required String bookingId,
    String paymentMethod = 'UPI',
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.payments,
        data: {'bookingId': bookingId, 'paymentMethod': paymentMethod},
      );
      if ((res.statusCode == 200 || res.statusCode == 201) &&
          res.data != null &&
          res.data['success'] == true) {
        return (
          success: true,
          message: res.data['message']?.toString() ?? 'Payment Successful! Session Confirmed.',
        );
      }
      return (
        success: false,
        message: res.data?['message']?.toString() ?? 'Payment failed.',
      );
    } on DioException catch (e) {
      String msg = 'Payment failed.';
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        msg = data['message'].toString();
      } else if (data is String) {
        try {
          final parsed = jsonDecode(data);
          if (parsed is Map && parsed['message'] != null) {
            msg = parsed['message'].toString();
          }
        } catch (_) {}
      } else if (e.response?.statusCode != null) {
        msg = 'Payment failed (${e.response?.statusCode}).';
      }
      return (success: false, message: msg);
    } catch (e) {
      return (success: false, message: 'Payment processing error: $e');
    }
  }
}
