import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../data/models/outlet_customer.dart';

class CustomerService {
  static const _basePath = '/api/outlet/customers/';

  static Future<String?> _authToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Uri _buildUri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(BASE_URL);
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final normalizedPath =
        path.startsWith('/') ? path : '/$path'; // ensure leading slash
    final combinedPath = (basePath + normalizedPath).replaceAll('//', '/');
    return base.replace(
      path: combinedPath.isEmpty ? '/' : combinedPath,
      queryParameters: query?.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
  }

  static Future<OutletCustomerPage> fetchCustomers({int page = 1}) async {
    final token = await _authToken();
    if (token == null) {
      throw Exception('Auth token not available');
    }

    final response = await http.get(
      _buildUri(_basePath, page > 1 ? {'page': page} : null),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return OutletCustomerPage.fromJson(decoded);
      } else if (decoded is List) {
        final results = decoded
            .whereType<Map<String, dynamic>>()
            .map(OutletCustomer.fromJson)
            .toList();
        return OutletCustomerPage(
          results: results,
          count: results.length,
          next: null,
          previous: null,
        );
      } else {
        throw Exception('Unexpected customers payload: ${decoded.runtimeType}');
      }
    }

    throw Exception(
      'Failed to fetch customers: ${response.statusCode} ${response.reasonPhrase}',
    );
  }

  static Future<OutletCustomer> createCustomer({
    required String name,
    required String mobile,
    String? email,
    String? subscriptionStatus,
    List<Map<String, dynamic>>? addresses,
  }) async {
    final token = await _authToken();
    if (token == null) {
      throw Exception('Auth token not available');
    }

    final payload = {
      'name': name,
      'mobile': mobile,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (subscriptionStatus != null && subscriptionStatus.trim().isNotEmpty)
        'subscription_status': subscriptionStatus.trim(),
      if (addresses != null && addresses.isNotEmpty) 'addresses': addresses,
    };

    print("[dkC] Payload: " + jsonEncode(payload));
    final response = await http.post(
      _buildUri(_basePath),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return OutletCustomer.fromJson(body);
    }

    final body = response.body;
    throw Exception(
      'Failed to create customer: ${response.statusCode} ${response.reasonPhrase}. $body',
    );
  }

  static Future<OutletCustomer> updateSuspension({
    required String customerId,
    required bool isSuspended,
    String? note,
  }) async {
    final token = await _authToken();
    if (token == null) {
      throw Exception('Auth token not available');
    }

    final payload = {
      'is_suspended': isSuspended,
      'suspension_note': note ?? '',
    };

    final response = await http.patch(
      _buildUri('$_basePath$customerId/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return OutletCustomer.fromJson(body);
    }

    final body = response.body;
    throw Exception(
      'Failed to update suspension: ${response.statusCode} ${response.reasonPhrase}. $body',
    );
  }

  static Future<OutletCustomer> updateCustomer({
    required String customerId,
    required String name,
    required String mobile,
    String? email,
    String? subscriptionStatus,
    List<Map<String, dynamic>>? addresses,
  }) async {
    final token = await _authToken();
    if (token == null) {
      throw Exception('Auth token not available');
    }

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

    final response = await http.patch(
      _buildUri('$_basePath$customerId/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return OutletCustomer.fromJson(body);
    }

    final body = response.body;
    throw Exception(
      'Failed to update customer: ${response.statusCode} ${response.reasonPhrase}. $body',
    );
  }
}
