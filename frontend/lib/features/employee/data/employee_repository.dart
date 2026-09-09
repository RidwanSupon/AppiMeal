import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

class EmployeeRepository {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getTodayStatus() async {
    final response = await _apiClient.get(ApiEndpoints.todayStatus);
    return response.data['data'];
  }

  Future<Map<String, dynamic>> attendLunch() async {
    try {
      final response = await _apiClient.post(ApiEndpoints.attend);
      return response.data;
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Failed to record attendance.';
      throw Exception(message);
    }
  }

  Future<Map<String, dynamic>> getCalendar({required int month, required int year}) async {
    final response = await _apiClient.get(ApiEndpoints.calendar, queryParameters: {
      'month': month,
      'year': year,
    });
    return response.data['data'];
  }

  Future<Map<String, dynamic>> scheduleLunch({required String lunchDate, required bool participate}) async {
    try {
      final response = await _apiClient.post(ApiEndpoints.schedule, data: {
        'lunch_date': lunchDate,
        'participate': participate,
      });
      return response.data;
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Failed to update schedule.';
      throw Exception(message);
    }
  }

  Future<Map<String, dynamic>> cancelLunch({required String lunchDate, String? reason}) async {
    try {
      final response = await _apiClient.post(ApiEndpoints.cancel, data: {
        'lunch_date': lunchDate,
        'reason': reason ?? 'Cancelled by employee',
      });
      return response.data;
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Failed to cancel lunch.';
      throw Exception(message);
    }
  }

  Future<Map<String, dynamic>> getMyLedger() async {
    final response = await _apiClient.get(ApiEndpoints.myLedger);
    return response.data['data'];
  }

  Future<Map<String, dynamic>> getEmployeeSummary() async {
    final response = await _apiClient.get('/dashboard/employee');
    return response.data['data'];
  }

  Future<Map<String, dynamic>> getTodayList() async {
    final response = await _apiClient.get(ApiEndpoints.todayList);
    return response.data['data'];
  }
}
