import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/flavor_config.dart';

/// Centralized API Service for all HTTP requests
/// Handles authentication, headers, and error handling
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  String? _cachedToken;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: FlavorConfig.instance.brandConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status != null && status < 500,
    ));

    // Add request interceptor for auth and headers
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add auth token
        final token = await _getAuthToken();
        if (token != null) {
          options.headers['Authorization'] = 'Token $token';
        }

        // Add brand ID header dynamically from flavor config (remove hyphens)
        final brandId = FlavorConfig.instance.brandConfig.brandId;
        options.headers['X-Brand-Id'] = brandId.replaceAll('-', '');

        // Add client app identifier
        options.headers['X-Client-App'] = "OUTLETM";

        // Ensure content type for POST/PATCH/PUT
        if (options.method == 'POST' ||
            options.method == 'PATCH' ||
            options.method == 'PUT') {
          options.headers['Content-Type'] = 'application/json';
        }

        if (kDebugMode) {
          debugPrint('🌐 ${options.method} ${options.uri}');
          debugPrint('📝 Headers: X-Brand-Id=${options.headers['X-Brand-Id']}');
          if (options.queryParameters.isNotEmpty) {
            debugPrint('📋 Query: ${options.queryParameters}');
          }
          if (options.data != null) {
            debugPrint('📦 Body: ${options.data}');
          }
        }

        return handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          debugPrint('✅ ${response.statusCode} ${response.requestOptions.uri}');
        }
        return handler.next(response);
      },
      onError: (error, handler) {
        if (kDebugMode) {
          debugPrint('❌ Error: ${error.message}');
          if (error.response != null) {
            debugPrint('❌ Status: ${error.response?.statusCode}');
            debugPrint('❌ Data: ${error.response?.data}');
          }
        }
        return handler.next(error);
      },
    ));
  }

  Future<String?> _getAuthToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('auth_token');
    return _cachedToken;
  }

  /// Clear cached token (call this on logout)
  void clearToken() {
    _cachedToken = null;
  }

  /// Refresh cached token (call this after login)
  Future<void> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('auth_token');
  }

  /// GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
       return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PATCH request
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle and transform DioException into user-friendly messages
  Exception _handleError(DioException error) {
    String message;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timeout. Please check your internet connection.';
        break;

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) {
          message = 'Authentication failed. Please login again.';
        } else if (statusCode == 403) {
          message = 'Access denied. You don\'t have permission.';
        } else if (statusCode == 404) {
          message = 'Resource not found.';
        } else if (statusCode == 422) {
          message = 'Invalid data provided.';
        } else {
          message = error.response?.data?['detail'] ??
              error.response?.data?['message'] ??
              'Server error (${statusCode ?? 'Unknown'})';
        }
        break;

      case DioExceptionType.cancel:
        message = 'Request cancelled.';
        break;

      case DioExceptionType.connectionError:
        message = 'No internet connection.';
        break;

      default:
        message = 'An unexpected error occurred.';
    }

    return ApiException(message, error.response?.statusCode);
  }
}

/// Custom API Exception
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}
