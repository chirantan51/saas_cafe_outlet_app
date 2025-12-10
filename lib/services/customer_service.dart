import 'package:dio/dio.dart';

import '../core/api_service.dart';
import '../data/models/outlet_customer.dart';

class CustomerService {
  static const _basePath = '/api/outlet/customers/';

  static Future<OutletCustomerPage> fetchCustomers({int page = 1}) async {
    final startTime = DateTime.now();
    print('⏱️ [fetchCustomers] Starting API call at ${startTime.toIso8601String()}');

    try {
      final apiService = ApiService();
      final apiCallStart = DateTime.now();

      final response = await apiService.get(
        _basePath,
        queryParameters: page > 1 ? {'page': page} : null,
      );

      final apiCallEnd = DateTime.now();
      final apiDuration = apiCallEnd.difference(apiCallStart).inMilliseconds;

      // Log response size
      final responseSize = response.data.toString().length;
      final responseSizeKB = (responseSize / 1024).toStringAsFixed(2);

      print('⏱️ [fetchCustomers] API call completed in ${apiDuration}ms');
      print('📦 [fetchCustomers] Response size: ${responseSizeKB}KB ($responseSize bytes)');

      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        final parseStart = DateTime.now();
        final decoded = response.data;

        OutletCustomerPage result;
        if (decoded is Map<String, dynamic>) {
          result = OutletCustomerPage.fromJson(decoded);
        } else if (decoded is List) {
          final results = decoded
              .whereType<Map<String, dynamic>>()
              .map(OutletCustomer.fromJson)
              .toList();
          result = OutletCustomerPage(
            results: results,
            count: results.length,
            next: null,
            previous: null,
          );
        } else {
          throw Exception('Unexpected customers payload: ${decoded.runtimeType}');
        }

        final parseEnd = DateTime.now();
        final parseDuration = parseEnd.difference(parseStart).inMilliseconds;
        final totalDuration = parseEnd.difference(startTime).inMilliseconds;

        final customerCount = result.results.length;
        final avgTimePerCustomer = customerCount > 0 ? (apiDuration / customerCount).toStringAsFixed(1) : '0';

        print('⏱️ [fetchCustomers] Parsing completed in ${parseDuration}ms');
        print('⏱️ [fetchCustomers] Total time: ${totalDuration}ms (${(totalDuration / 1000).toStringAsFixed(2)}s)');
        print('⏱️ [fetchCustomers] Breakdown: API=${apiDuration}ms, Parse=${parseDuration}ms');
        print('👥 [fetchCustomers] Loaded $customerCount customers (~${avgTimePerCustomer}ms per customer)');

        // Performance warning
        if (apiDuration > 2000) {
          print('⚠️ [fetchCustomers] WARNING: API response time is very slow (${apiDuration}ms)!');
          print('   Expected: <1000ms for 50 customers');
          print('   Recommendation: Check backend API performance');
        }

        return result;
      }

      throw Exception(
        'Failed to fetch customers: ${response.statusCode} ${response.statusMessage}',
      );
    } catch (e) {
      final endTime = DateTime.now();
      final totalDuration = endTime.difference(startTime).inMilliseconds;
      print('❌ [fetchCustomers] Failed after ${totalDuration}ms: $e');

      if (e is DioException) {
        throw Exception(
          'Failed to fetch customers: ${e.response?.statusCode} ${e.message}',
        );
      }
      rethrow;
    }
  }

  static Future<OutletCustomer> createCustomer({
    required String name,
    required String mobile,
    String? email,
    String? subscriptionStatus,
    List<Map<String, dynamic>>? addresses,
  }) async {
    try {
      final payload = {
        'name': name,
        'mobile': mobile,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (subscriptionStatus != null && subscriptionStatus.trim().isNotEmpty)
          'subscription_status': subscriptionStatus.trim(),
        if (addresses != null && addresses.isNotEmpty) 'addresses': addresses,
      };

      final apiService = ApiService();
      final response = await apiService.post(
        _basePath,
        data: payload,
      );

      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        final body = response.data as Map<String, dynamic>;
        return OutletCustomer.fromJson(body);
      }

      throw Exception(
        'Failed to create customer: ${response.statusCode} ${response.statusMessage}',
      );
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Failed to create customer: ${e.response?.statusCode} ${e.message} - ${e.response?.data}',
        );
      }
      rethrow;
    }
  }

  static Future<OutletCustomer> updateSuspension({
    required String customerId,
    required bool isSuspended,
    String? note,
  }) async {
    try {
      final payload = {
        'is_suspended': isSuspended,
        'suspension_note': note ?? '',
      };

      final apiService = ApiService();
      final response = await apiService.patch(
        '$_basePath$customerId/',
        data: payload,
      );

      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        final body = response.data as Map<String, dynamic>;
        return OutletCustomer.fromJson(body);
      }

      throw Exception(
        'Failed to update suspension: ${response.statusCode} ${response.statusMessage}',
      );
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Failed to update suspension: ${e.response?.statusCode} ${e.message} - ${e.response?.data}',
        );
      }
      rethrow;
    }
  }

  static Future<OutletCustomer> updateCustomer({
    required String customerId,
    required String name,
    required String mobile,
    String? email,
    String? subscriptionStatus,
    List<Map<String, dynamic>>? addresses,
  }) async {
    try {
      final payload = <String, dynamic>{
        'name': name,
        'mobile': mobile,
      };
      final trimmedEmail = email?.trim();
      if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
        payload['email'] = trimmedEmail;
      }
      final trimmedStatus = subscriptionStatus?.trim();
      if (trimmedStatus != null && trimmedStatus.isNotEmpty) {
        payload['subscription_status'] = trimmedStatus;
      }
      if (addresses != null) {
        payload['addresses'] = addresses;
      }

      final apiService = ApiService();
      final response = await apiService.patch(
        '$_basePath$customerId/',
        data: payload,
      );

      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        final body = response.data as Map<String, dynamic>;
        return OutletCustomer.fromJson(body);
      }

      throw Exception(
        'Failed to update customer: ${response.statusCode} ${response.statusMessage}',
      );
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Failed to update customer: ${e.response?.statusCode} ${e.message} - ${e.response?.data}',
        );
      }
      rethrow;
    }
  }
}
