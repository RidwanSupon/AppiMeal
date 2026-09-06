import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

class AdminRepository {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getAdminSummary() async {
    final response = await _apiClient.get(ApiEndpoints.adminSummary);
    return response.data['data'];
  }

  Future<Map<String, dynamic>> getCateringSummary() async {
    final response = await _apiClient.get(ApiEndpoints.cateringSummary);
    return response.data['data'];
  }

  Future<Map<String, dynamic>> getEmployees({String? search, String? department, String? status}) async {
    final response = await _apiClient.get(ApiEndpoints.employees, queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (department != null && department.isNotEmpty) 'department': department,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return response.data['data'];
  }

  Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(ApiEndpoints.employees, data: data);
      return response.data;
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Failed to create employee.';
      throw Exception(message);
    }
  }

  Future<Map<String, dynamic>> updateEmployee(int id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.put('${ApiEndpoints.employees}/$id', data: data);
      return response.data;
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Failed to update employee.';
      throw Exception(message);
    }
  }

  Future<Map<String, dynamic>> resetEmployeePassword(int id, String password) async {
    try {
      final response = await _apiClient.post('${ApiEndpoints.employees}/$id/reset-password', data: {'password': password});
      return response.data;
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Failed to reset password.';
      throw Exception(message);
    }
  }

  Future<Map<String, dynamic>> toggleEmployeeStatus(int id) async {
    final response = await _apiClient.patch('${ApiEndpoints.employees}/$id/status');
    return response.data;
  }

  Future<Map<String, dynamic>> getPayments({int? employeeId}) async {
    final Map<String, dynamic> query = {};
    if (employeeId != null) query['employee_id'] = employeeId;
    final response = await _apiClient.get(ApiEndpoints.payments, queryParameters: query);
    return response.data['data'];
  }

  Future<Map<String, dynamic>> recordPayment(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(ApiEndpoints.payments, data: data);
      return response.data;
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Failed to record payment.';
      throw Exception(message);
    }
  }

  Future<Map<String, dynamic>> getSettings() async {
    final response = await _apiClient.get(ApiEndpoints.settings);
    return response.data['data'];
  }

  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.put(ApiEndpoints.settings, data: data);
      return response.data;
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Failed to update settings.';
      throw Exception(message);
    }
  }

  Future<Map<String, dynamic>> getDailyReport(String date) async {
    final response = await _apiClient.get(ApiEndpoints.reportsDaily, queryParameters: {'date': date});
    return response.data['data'];
  }

  Future<Map<String, dynamic>> getMonthlyReport(int month, int year) async {
    final response = await _apiClient.get(ApiEndpoints.reportsMonthly, queryParameters: {'month': month, 'year': year});
    return response.data['data'];
  }

  Future<Map<String, dynamic>> getEmployeeReport() async {
    final response = await _apiClient.get(ApiEndpoints.reportsEmployees);
    return response.data['data'];
  }

  Future<Map<String, dynamic>> getDueReport() async {
    final response = await _apiClient.get(ApiEndpoints.reportsDues);
    return response.data['data'];
  }

  Future<Map<String, dynamic>> getAuditLogs() async {
    final response = await _apiClient.get(ApiEndpoints.auditLogs);
    return response.data['data'];
  }

  Future<Map<String, dynamic>> getAdminCateringSummary() async {
    final response = await _apiClient.get(ApiEndpoints.adminCateringSummary);
    return response.data['data'];
  }

  Future<Map<String, dynamic>> getCateringPayments() async {
    final response = await _apiClient.get(ApiEndpoints.cateringPayments);
    return response.data['data'];
  }

  Future<Map<String, dynamic>> recordCateringPayment(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(ApiEndpoints.cateringPayments, data: data);
      return response.data;
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Failed to record catering payment.';
      throw Exception(message);
    }
  }

  Future<Map<String, dynamic>> getEmployeeMealBreakdown() async {
    final response = await _apiClient.get(ApiEndpoints.cateringEmployeeBreakdown);
    return response.data['data'];
  }

  Future<Map<String, dynamic>> getAdminManageList({String? date, String? search, String? department}) async {
    final response = await _apiClient.get(ApiEndpoints.adminManageList, queryParameters: {
      if (date != null && date.isNotEmpty) 'date': date,
      if (search != null && search.isNotEmpty) 'search': search,
      if (department != null && department.isNotEmpty) 'department': department,
    });
    return response.data['data'];
  }

  Future<Map<String, dynamic>> manualManageMeal(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(ApiEndpoints.adminManageMeal, data: data);
      return response.data;
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Failed to update meal status.';
      throw Exception(message);
    }
  }
}
