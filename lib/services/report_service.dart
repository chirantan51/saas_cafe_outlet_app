import 'package:dio/dio.dart';

import '../core/api_service.dart';

class ReportService {
  /// Get Sales Report
  /// period: 'today', 'week', 'month', 'custom'
  /// startDate & endDate: for custom period (YYYY-MM-DD format)
  Future<Map<String, dynamic>> getSalesReport({
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

      final apiService = ApiService();
      final response = await apiService.get(
        '/api/reports/sales/',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to fetch sales report');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Error fetching sales report: ${e.response?.statusCode} ${e.message}',
        );
      }
      rethrow;
    }
  }

  /// Get Products & Sold Quantity Report
  /// period: 'today', 'week', 'month', 'custom'
  /// startDate & endDate: for custom period (YYYY-MM-DD format)
  Future<List<Map<String, dynamic>>> getProductsReport({
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

      final apiService = ApiService();
      final response = await apiService.get(
        '/api/reports/products/',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['products'] != null) {
          return List<Map<String, dynamic>>.from(data['products']);
        }
        return [];
      } else {
        throw Exception('Failed to fetch products report');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Error fetching products report: ${e.response?.statusCode} ${e.message}',
        );
      }
      rethrow;
    }
  }

  /// Get Customer-Wise Sales Report
  /// period: 'today', 'week', 'month', 'custom'
  /// startDate & endDate: for custom period (YYYY-MM-DD format)
  Future<List<Map<String, dynamic>>> getCustomerSalesReport({
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

      final apiService = ApiService();
      final response = await apiService.get(
        '/api/reports/customers/',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['customers'] != null) {
          return List<Map<String, dynamic>>.from(data['customers']);
        }
        return [];
      } else {
        throw Exception('Failed to fetch customer sales report');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Error fetching customer sales report: ${e.response?.statusCode} ${e.message}',
        );
      }
      rethrow;
    }
  }
}
