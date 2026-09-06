import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();
  final SecureStorageService _storage = SecureStorageService();

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _apiClient.post(ApiEndpoints.login, data: {
        'email': email,
        'password': password,
      });

      final data = response.data['data'];
      final token = data['token'];
      final user = data['user'];

      await _storage.saveAuthData(
        token: token,
        role: user['role'] ?? 'employee',
        email: user['email'] ?? '',
        name: user['name'] ?? '',
      );

      return data;
    } on DioException catch (e) {
      final serverMessage = e.response?.data['message'];
      if (serverMessage != null && serverMessage.toString().isNotEmpty) {
        throw Exception(serverMessage);
      }
      final host = e.requestOptions.baseUrl;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw Exception('Network Error: Cannot connect to $host. Please check your internet connection or host IP.');
      }
      throw Exception('Connection failed ($host): ${e.message ?? 'Unknown network issue'}');
    }
  }

  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.me);
      return response.data['data'];
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.post(ApiEndpoints.logout);
    } catch (_) {}
    await _storage.clearAuthData();
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await _apiClient.post(ApiEndpoints.forgotPassword, data: {'email': email});
    return response.data;
  }

  Future<Map<String, dynamic>> uploadAvatar(dynamic imageFile) async {
    try {
      final String filePath = imageFile.path;
      final fileName = filePath.split('/').last;
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
        ),
      });

      final response = await _apiClient.post(
        ApiEndpoints.uploadAvatar,
        data: formData,
      );

      return response.data['data'];
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Failed to upload avatar.';
      throw Exception(message);
    }
  }
}
