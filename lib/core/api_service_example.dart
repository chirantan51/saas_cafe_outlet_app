/// EXAMPLE: How to use the centralized ApiService
///
/// This file demonstrates the usage patterns for ApiService.
/// Delete this file once you're familiar with the API.

import 'api_service.dart';

class ExampleService {
  final ApiService _api = ApiService();

  /// Example 1: Simple GET request
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _api.get('/api/profile/');

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to fetch profile');
      }
    } on ApiException catch (e) {
      // ApiException has user-friendly error messages
      throw Exception(e.message);
    }
  }

  /// Example 2: GET with query parameters
  Future<List<Map<String, dynamic>>> getOrders({
    required String period,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{'period': period};
      if (period == 'custom' && startDate != null && endDate != null) {
        queryParams['start_date'] = startDate;
        queryParams['end_date'] = endDate;
      }

      final response = await _api.get(
        '/api/orders/',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['orders'] != null) {
          return List<Map<String, dynamic>>.from(data['orders']);
        }
        return [];
      } else {
        throw Exception('Failed to fetch orders');
      }
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Example 3: POST request
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await _api.post(
        '/api/orders/',
        data: orderData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to create order');
      }
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Example 4: PATCH request
  Future<bool> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    try {
      final response = await _api.patch(
        '/api/orders/$orderId/change-status/',
        data: {'status': status},
      );

      return response.statusCode == 200;
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Example 5: DELETE request
  Future<bool> deleteOrder(String orderId) async {
    try {
      final response = await _api.delete('/api/orders/$orderId/');
      return response.statusCode == 200 || response.statusCode == 204;
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Example 6: Handling different response types
  Future<dynamic> getFlexibleData(String endpoint) async {
    try {
      final response = await _api.get(endpoint);

      if (response.statusCode == 200) {
        final data = response.data;

        // Handle different response structures
        if (data is Map<String, dynamic>) {
          // Single object response
          return data;
        } else if (data is List) {
          // Array response
          return data;
        } else {
          // Primitive type (string, number, etc.)
          return data;
        }
      } else {
        throw Exception('Request failed');
      }
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }
}

/// NOTES:
///
/// 1. Auth Token & Brand ID Header:
///    - Automatically added to ALL requests
///    - No need to manually add these headers
///
/// 2. Error Handling:
///    - ApiException contains user-friendly error messages
///    - Always wrap calls in try-catch
///
/// 3. Base URL:
///    - Already included, just provide the path (e.g., '/api/orders/')
///
/// 4. Debug Logging:
///    - Automatically logs requests/responses in debug mode
///    - Check console for 🌐 (request), ✅ (success), ❌ (error)
///
/// 5. Token Management:
///    - Call ApiService().refreshToken() after login
///    - Call ApiService().clearToken() on logout
