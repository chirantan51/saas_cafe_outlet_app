import 'package:dio/dio.dart';
import 'package:outlet_app/data/models/plan_subscription.dart';
import 'package:outlet_app/data/models/subscription_detail.dart';
import 'package:outlet_app/data/models/subscription_plan.dart';
import 'package:outlet_app/data/models/subscription_models.dart';

import '../core/api_service.dart';

class SubscriptionService {
  const SubscriptionService._();

  static Future<List<SubscriptionPlan>> fetchPlans() async {
    try {
      final apiService = ApiService();
      final response = await apiService.get('/api/subscriptions/plans/');

      if (response.statusCode != 200) {
        throw Exception('Failed to load subscription plans');
      }

      final data = response.data;
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
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Failed to fetch subscription plans: ${e.response?.statusCode} ${e.message}',
        );
      }
      rethrow;
    }
  }

  static Future<List<PlanSubscription>> fetchPlanSubscriptions(
      int planId) async {
    try {
      final apiService = ApiService();
      final response = await apiService.get(
        '/api/subscriptions/plans/$planId/subscriptions/',
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load plan subscriptions');
      }

      final data = response.data;
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
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Failed to fetch plan subscriptions: ${e.response?.statusCode} ${e.message}',
        );
      }
      rethrow;
    }
  }

  static Future<void> createPlan(Map<String, dynamic> payload) async {
    try {
      final apiService = ApiService();
      final response = await apiService.post(
        '/api/subscriptions/plans/',
        data: payload,
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to create subscription plan');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Failed to create plan: ${e.response?.statusCode} ${e.message}',
        );
      }
      rethrow;
    }
  }

  static Future<void> updatePlan(int planId, Map<String, dynamic> payload) async {
    try {
      final apiService = ApiService();
      final response = await apiService.patch(
        '/api/subscriptions/plans/$planId/',
        data: payload,
      );

      if (response.statusCode! < 200 || response.statusCode! >= 300) {
        throw Exception('Failed to update subscription plan');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Failed to update plan: ${e.response?.statusCode} ${e.message}',
        );
      }
      rethrow;
    }
  }

  static Future<void> deletePlan(int planId) async {
    try {
      final apiService = ApiService();
      final response = await apiService.delete(
        '/api/subscriptions/plans/$planId/',
      );

      if (response.statusCode! < 200 || response.statusCode! >= 300) {
        String errorMsg = 'Failed to delete subscription plan';
        final errData = response.data;
        if (errData is Map && errData['detail'] is String) {
          errorMsg = errData['detail'];
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (e is DioException) {
        String errorMsg = 'Failed to delete plan';
        final errData = e.response?.data;
        if (errData is Map && errData['detail'] is String) {
          errorMsg = errData['detail'];
        } else if (e.response?.statusCode != null) {
          errorMsg = '$errorMsg: ${e.response?.statusCode}';
        }
        throw Exception(errorMsg);
      }
      rethrow;
    }
  }

  static Future<SubscriptionDetail> fetchSubscriptionDetail(int id) async {
    try {
      final apiService = ApiService();
      final response = await apiService.get('/api/subscriptions/$id/');

      if (response.statusCode != 200) {
        throw Exception('Failed to load subscription detail');
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return SubscriptionDetail.fromJson(data);
      }

      throw Exception('Unexpected response format for subscription detail');
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Failed to fetch subscription detail: ${e.response?.statusCode} ${e.message}',
        );
      }
      rethrow;
    }
  }

  static Future<SubscriptionQuote> fetchSubscriptionQuote({
    required String productId,
    required String customerId,
    required List<Map<String, dynamic>> days,
    String? addressId,
    String? paymentMethod,
    String? paymentStatus,
  }) async {
    try {
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

      final apiService = ApiService();
      final response = await apiService.post(
        '/api/subscriptions/quote/',
        data: payload,
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to fetch subscription quote: ${response.statusCode} ${response.statusMessage}');
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return SubscriptionQuote.fromJson(data);
      }

      throw Exception('Unexpected response format for subscription quote');
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Failed to fetch subscription quote: ${e.response?.statusCode} ${e.message} - ${e.response?.data}',
        );
      }
      rethrow;
    }
  }

  static Future<SubscriptionQuoteResponse> getSubscriptionQuote({
    required String productId,
    required String addressId,
    required String customerId,
    required List<Map<String, dynamic>> dates,
  }) async {
    try {
      final payload = {
        'product_id': productId,
        'address_id': addressId,
        'customer_id': customerId,
        'dates': dates,
      };

      final apiService = ApiService();
      final response = await apiService.post(
        '/api/subscriptions/quote/',
        data: payload,
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to get subscription quote: ${response.statusCode} ${response.statusMessage}');
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return SubscriptionQuoteResponse.fromJson(data);
      }

      throw Exception('Unexpected response format for subscription quote');
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Failed to get subscription quote: ${e.response?.statusCode} ${e.message} - ${e.response?.data}',
        );
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createSubscription({
    required String productId,
    required String customerId,
    required String addressId,
    required List<Map<String, dynamic>> days,
    String paymentMethod = 'prepaid',
    String paymentStatus = 'Pending',
  }) async {
    try {
      final payload = {
        'product_id': productId,
        'customer_id': customerId,
        'days': days,
        'address_id': addressId,
        'payment_method': paymentMethod,
        'payment_status': paymentStatus,
      };

      final apiService = ApiService();
      final response = await apiService.post(
        '/api/subscriptions/create/',
        data: payload,
      );

      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        final data = response.data;
        return data is Map<String, dynamic> ? data : {};
      } else {
        String errorMsg = 'Create failed: ${response.statusCode}';
        final errData = response.data;
        if (errData is Map && errData['error'] is String) {
          errorMsg = errData['error'];
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (e is DioException) {
        String errorMsg = 'Create failed: ${e.response?.statusCode}';
        final errData = e.response?.data;
        if (errData is Map && errData['error'] is String) {
          errorMsg = errData['error'];
        }
        throw Exception(errorMsg);
      }
      rethrow;
    }
  }

  static Future<void> updateSubscriptionSchedule({
    required int subscriptionId,
    required List<Map<String, dynamic>> days,
  }) async {
    try {
      final payload = {
        'days': days,
      };

      final apiService = ApiService();
      final response = await apiService.patch(
        '/api/subscriptions/$subscriptionId/reschedule/',
        data: payload,
      );

      if (response.statusCode! < 200 || response.statusCode! >= 300) {
        String errorMsg = 'Reschedule failed: ${response.statusCode}';
        final errData = response.data;
        if (errData is Map && errData['error'] is String) {
          errorMsg = errData['error'];
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (e is DioException) {
        String errorMsg = 'Reschedule failed: ${e.response?.statusCode}';
        final errData = e.response?.data;
        if (errData is Map && errData['error'] is String) {
          errorMsg = errData['error'];
        }
        throw Exception(errorMsg);
      }
      rethrow;
    }
  }

  static Future<void> updateSubscription({
    required int subscriptionId,
    required List<Map<String, dynamic>> days,
    String? slotLabel,
  }) async {
    try {
      final payload = <String, dynamic>{
        'days': days,
      };

      if (slotLabel != null) {
        payload['slot_label'] = slotLabel;
      }

      final apiService = ApiService();
      final response = await apiService.patch(
        '/api/subscriptions/$subscriptionId/plan/',
        data: payload,
      );

      if (response.statusCode! < 200 || response.statusCode! >= 300) {
        String errorMsg = 'Update subscription failed: ${response.statusCode}';
        final errData = response.data;
        if (errData is Map && errData['error'] is String) {
          errorMsg = errData['error'];
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (e is DioException) {
        String errorMsg = 'Update subscription failed: ${e.response?.statusCode}';
        final errData = e.response?.data;
        if (errData is Map && errData['error'] is String) {
          errorMsg = errData['error'];
        }
        throw Exception(errorMsg);
      }
      rethrow;
    }
  }

  static Future<void> updatePaymentDetails({
    required int subscriptionId,
    String? paymentMethod,
    String? paymentStatus,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (paymentMethod != null) payload['payment_method'] = paymentMethod;
      if (paymentStatus != null) payload['payment_status'] = paymentStatus;

      final apiService = ApiService();
      final response = await apiService.patch(
        '/api/subscriptions/$subscriptionId/payment/',
        data: payload,
      );

      if (response.statusCode! < 200 || response.statusCode! >= 300) {
        String errorMsg = 'Payment update failed: ${response.statusCode}';
        final errData = response.data;
        if (errData is Map && errData['error'] is String) {
          errorMsg = errData['error'];
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (e is DioException) {
        String errorMsg = 'Payment update failed: ${e.response?.statusCode}';
        final errData = e.response?.data;
        if (errData is Map && errData['error'] is String) {
          errorMsg = errData['error'];
        }
        throw Exception(errorMsg);
      }
      rethrow;
    }
  }

  static Future<void> updateSubscriptionStatus({
    required int subscriptionId,
    required String status,
    required String reason,
  }) async {
    try {
      final payload = {
        'status': status,
        'reason': reason,
      };

      final apiService = ApiService();
      final response = await apiService.patch(
        '/api/subscriptions/$subscriptionId/status/',
        data: payload,
      );

      if (response.statusCode! < 200 || response.statusCode! >= 300) {
        String errorMsg = 'Status update failed';
        final errData = response.data;
        if (errData is Map) {
          if (errData['detail'] is String) {
            errorMsg = errData['detail'];
          } else if (errData['status'] is List && (errData['status'] as List).isNotEmpty) {
            errorMsg = errData['status'][0].toString();
          } else if (errData['reason'] is List && (errData['reason'] as List).isNotEmpty) {
            errorMsg = errData['reason'][0].toString();
          }
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (e is DioException) {
        String errorMsg = 'Status update failed';
        final errData = e.response?.data;
        if (errData is Map) {
          if (errData['detail'] is String) {
            errorMsg = errData['detail'];
          } else if (errData['status'] is List && (errData['status'] as List).isNotEmpty) {
            errorMsg = errData['status'][0].toString();
          } else if (errData['reason'] is List && (errData['reason'] as List).isNotEmpty) {
            errorMsg = errData['reason'][0].toString();
          }
        }
        throw Exception(errorMsg);
      }
      rethrow;
    }
  }
}
