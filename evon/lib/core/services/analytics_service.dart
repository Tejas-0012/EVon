import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'api_service.dart';

class AnalyticsService {
  final Dio _dio = ApiService().dio;

  Future<Map<String, dynamic>?> getAdminOverview() async {
    try {
      final res = await _dio.get(ApiConstants.adminOverview);
      if (res.statusCode == 200 && res.data['success'] == true) {
        return res.data['metrics'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getLoadForecast() async {
    try {
      final res = await _dio.get(ApiConstants.loadForecast);
      if (res.statusCode == 200 && res.data['success'] == true) {
        final List list = res.data['forecast'] ?? [];
        return List<Map<String, dynamic>>.from(list);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
