import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';
import '../storage/secure_storage_service.dart';

class ApiClient {
  late final Dio _dio;
  final SecureStorageService _storage = SecureStorageService();

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final customUrl = await _storage.getServerUrl();
          if (customUrl != null && customUrl.isNotEmpty) {
            options.baseUrl = customUrl.endsWith('/')
                ? '${customUrl}api'
                : (customUrl.endsWith('/api') ? customUrl : '$customUrl/api');
          }
          final token = await _storage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          // Log request in debug/release for diagnostic output
          // ignore: avoid_print
          print('[ApiClient] Request ➔ ${options.method} ${options.baseUrl}${options.path}');
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // ignore: avoid_print
          print('[ApiClient] Error ➔ ${error.type} on ${error.requestOptions.baseUrl}${error.requestOptions.path}: ${error.message}');
          if (error.response?.statusCode == 401) {
            await _storage.clearAuthData();
          }
          return handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> patch(String path, {dynamic data}) async {
    try {
      return await _dio.patch(path, data: data);
    } catch (e) {
      rethrow;
    }
  }
}
