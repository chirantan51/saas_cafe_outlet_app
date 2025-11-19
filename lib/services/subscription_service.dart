import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:outlet_app/constants.dart';
import 'package:outlet_app/data/models/plan_subscription.dart';
import 'package:outlet_app/data/models/subscription_detail.dart';
import 'package:outlet_app/data/models/subscription_plan.dart';
import 'package:outlet_app/data/models/subscription_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService {
  const SubscriptionService._();

  static Future<List<SubscriptionPlan>> fetchPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('Missing auth token');
    }

    final uri = Uri.parse('$BASE_URL/api/subscriptions/plans/');
    final response = await http.get(uri, headers: {
      'Authorization': 'Token $token',
      'Content-Type': 'application/json',
    });

    if (response.statusCode != 200) {
      throw Exception('Failed to load subscription plans');
    }

    final data = jsonDecode(response.body);
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(SubscriptionPlan.fromJson)
          .toList();
    }

    if (data is Map<String, dynamic> && data['results'] is List) {
      return (data['results'] as List)
          .whereType<Map<String, dynamic>>()
          .map(SubscriptionPlan.fromJson)
          .toList();
    }

    throw Exception('Unexpected response format for subscription plans');
  }

  static Future<List<PlanSubscription>> fetchPlanSubscriptions(
      int planId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('Missing auth token');
    }

    final uri =
        Uri.parse('$BASE_URL/api/subscriptions/plans/$planId/subscriptions/');
    final response = await http.get(uri, headers: {
      'Authorization': 'Token $token',
      'Content-Type': 'application/json',
    });

    if (response.statusCode != 200) {
      throw Exception('Failed to load plan subscriptions');
    }

    final data = jsonDecode(response.body);
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(PlanSubscription.fromJson)
          .toList();
    }

    if (data is Map<String, dynamic> && data['results'] is List) {
      return (data['results'] as List)
          .whereType<Map<String, dynamic>>()
          .map(PlanSubscription.fromJson)
          .toList();
    }

    throw Exception('Unexpected response format for plan subscriptions');
  }

  static Future<void> createPlan(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('Missing auth token');
    }

    final response = await http.post(
      Uri.parse('$BASE_URL/api/subscriptions/plans/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to create subscription plan');
    }
  }

  static Future<void> updatePlan(int planId, Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('Missing auth token');
    }

    final response = await http.patch(
      Uri.parse('$BASE_URL/api/subscriptions/plans/$planId/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to update subscription plan');
    }
  }

  static Future<SubscriptionDetail> fetchSubscriptionDetail(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('Missing auth token');
    }

    final uri = Uri.parse('$BASE_URL/api/subscriptions/$id/');
    final response = await http.get(uri, headers: {
      'Authorization': 'Token $token',
      'Content-Type': 'application/json',
    });

    if (response.statusCode != 200) {
      throw Exception('Failed to load subscription detail');
    }

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) {
      return SubscriptionDetail.fromJson(data);
    }

    throw Exception('Unexpected response format for subscription detail');
  }

  static Future<SubscriptionQuote> fetchSubscriptionQuote({
    required String productId,
    required String customerId,
    required List<Map<String, dynamic>> days,
    String? addressId,
    String? paymentMethod,
    String? paymentStatus,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('Missing auth token');
    }

    final payload = <String, dynamic>{
      'product_id': productId,
      'customer_id': customerId,
      'days': days,
      if (addressId != null && addressId.isNotEmpty) 'address_id': addressId,
      if (paymentMethod != null && paymentMethod.isNotEmpty)
        'payment_method': paymentMethod,
      if (paymentStatus != null && paymentStatus.isNotEmpty)
        'payment_status': paymentStatus,
    };

    final response = await http.post(
      Uri.parse('$BASE_URL/api/subscriptions/quote/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to fetch subscription quote: ${response.statusCode} ${response.reasonPhrase ?? ''} - ${response.body}');
    }

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) {
      return SubscriptionQuote.fromJson(data);
    }

    throw Exception('Unexpected response format for subscription quote');
  }

  static Future<Map<String, dynamic>> createSubscription({
    required String productId,
    required String customerId,
    required String addressId,
    required List<Map<String, dynamic>> days,
    String paymentMethod = 'prepaid',
    String paymentStatus = 'Pending',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('Missing auth token');
    }

    final payload = {
      'product_id': productId,
      'customer_id': customerId,
      'days': days,
      'address_id': addressId,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
    };

    final response = await http.post(
      Uri.parse('$BASE_URL/api/subscriptions/create/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Success - return the response data
      try {
        final data = jsonDecode(response.body);
        return data is Map<String, dynamic> ? data : {};
      } catch (_) {
        return {};
      }
    } else {
      // Error - try to parse error message
      String errorMsg = 'Create failed: ${response.statusCode}';
      try {
        final errData = jsonDecode(response.body);
        if (errData is Map && errData['error'] is String) {
          errorMsg = errData['error'];
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  static Future<void> updateSubscriptionSchedule({
    required int subscriptionId,
    required List<Map<String, dynamic>> days,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('Missing auth token');
    }

    final payload = {
      'days': days,
    };

    final response = await http.patch(
      Uri.parse('$BASE_URL/api/subscriptions/$subscriptionId/reschedule/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMsg = 'Reschedule failed: ${response.statusCode}';
      try {
        final errData = jsonDecode(response.body);
        if (errData is Map && errData['error'] is String) {
          errorMsg = errData['error'];
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  static Future<void> updateSubscription({
    required int subscriptionId,
    required List<Map<String, dynamic>> days,
    String? slotLabel,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('Missing auth token');
    }

    final payload = <String, dynamic>{
      'days': days,
    };

    if (slotLabel != null) {
      payload['slot_label'] = slotLabel;
    }

    final response = await http.patch(
      Uri.parse('$BASE_URL/api/subscriptions/$subscriptionId/plan/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMsg = 'Update subscription failed: ${response.statusCode}';
      try {
        final errData = jsonDecode(response.body);
        if (errData is Map && errData['error'] is String) {
          errorMsg = errData['error'];
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  static Future<void> updatePaymentDetails({
    required int subscriptionId,
    String? paymentMethod,
    String? paymentStatus,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('Missing auth token');
    }

    final payload = <String, dynamic>{};
    if (paymentMethod != null) payload['payment_method'] = paymentMethod;
    if (paymentStatus != null) payload['payment_status'] = paymentStatus;

    final response = await http.patch(
      Uri.parse('$BASE_URL/api/subscriptions/$subscriptionId/payment/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMsg = 'Payment update failed: ${response.statusCode}';
      try {
        final errData = jsonDecode(response.body);
        if (errData is Map && errData['error'] is String) {
          errorMsg = errData['error'];
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  static Future<void> updateSubscriptionStatus({
    required int subscriptionId,
    required String status,
    String? reason,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('Missing auth token');
    }

    final payload = {
      'status': status,
      if (reason != null) 'reason': reason,
    };

    final response = await http.patch(
      Uri.parse('$BASE_URL/api/subscriptions/$subscriptionId/status/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMsg = 'Status update failed: ${response.statusCode}';
      try {
        final errData = jsonDecode(response.body);
        if (errData is Map && errData['error'] is String) {
          errorMsg = errData['error'];
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }
}
