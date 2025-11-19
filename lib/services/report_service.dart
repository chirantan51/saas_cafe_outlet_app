import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class ReportService {
  final Dio _dio = Dio();

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Get Sales Report
  /// period: 'today', 'week', 'month', 'custom'
  /// startDate & endDate: for custom period (YYYY-MM-DD format)
  Future<Map<String, dynamic>> getSalesReport({
    required String period,
    String? startDate,
    String? endDate,
  }) async {
    final token = await _getAuthToken();
    if (token == null) throw Exception('Not authenticated');

    final queryParams = <String, dynamic>{'period': period};
    if (period == 'custom' && startDate != null && endDate != null) {
      queryParams['start_date'] = startDate;
      queryParams['end_date'] = endDate;
    }

    try {
      final response = await _dio.get(
        '$BASE_URL/api/reports/sales/',
        queryParameters: queryParams,
        options: Options(
          headers: {'Authorization': 'Token $token'},
        ),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to fetch sales report');
      }
    } catch (e) {
      throw Exception('Error fetching sales report: $e');
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
    final token = await _getAuthToken();
    if (token == null) throw Exception('Not authenticated');

    final queryParams = <String, dynamic>{'period': period};
    if (period == 'custom' && startDate != null && endDate != null) {
      queryParams['start_date'] = startDate;
      queryParams['end_date'] = endDate;
    }

    try {
      final response = await _dio.get(
        '$BASE_URL/api/reports/products/',
        queryParameters: queryParams,
        options: Options(
          headers: {'Authorization': 'Token $token'},
        ),
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
      throw Exception('Error fetching products report: $e');
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
    final token = await _getAuthToken();
    if (token == null) throw Exception('Not authenticated');

    final queryParams = <String, dynamic>{'period': period};
    if (period == 'custom' && startDate != null && endDate != null) {
      queryParams['start_date'] = startDate;
      queryParams['end_date'] = endDate;
    }

    try {
      final response = await _dio.get(
        '$BASE_URL/api/reports/customers/',
        queryParameters: queryParams,
        options: Options(
          headers: {'Authorization': 'Token $token'},
        ),
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
      throw Exception('Error fetching customer sales report: $e');
    }
  }
}
