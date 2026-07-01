import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      'ApiException(${statusCode ?? '-'}): $message';
}

class ApiClient {
  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) {
        final status = e.response?.statusCode;
        final msg = _extractMessage(e, status);
        handler.reject(DioException(
          requestOptions: e.requestOptions,
          response: e.response,
          type: e.type,
          error: ApiException(msg, statusCode: status),
        ));
      },
    ));
  }

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static final ApiClient instance = ApiClient._internal();

  late final Dio _dio;

  Dio get dio => _dio;

  /// Best-effort extraction of a *readable* message from a Dio error.
  /// Skips Dio's default verbose text ("This exception was thrown because
  /// the response has a status code…") when the response body carries no
  /// usable field.
  static String _extractMessage(DioException e, int? status) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'] ?? data['error'] ?? data['message'];
      if (detail != null) return detail.toString();
      // DRF field errors: {"email": ["already exists"]}
      for (final entry in data.entries) {
        final v = entry.value;
        if (v is List && v.isNotEmpty) return '${entry.key}: ${v.first}';
        if (v is String && v.isNotEmpty) return '${entry.key}: $v';
      }
    }
    if (status != null && status >= 500) return 'Server error ($status)';
    if (status != null && status >= 400) return 'Request failed ($status)';
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Server is slow to respond';
      case DioExceptionType.connectionError:
        return 'Could not reach the server';
      default:
        return 'Network error';
    }
  }
}
