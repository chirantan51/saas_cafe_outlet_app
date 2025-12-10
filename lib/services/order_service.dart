import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import 'package:outlet_app/core/api_service.dart';

Future<bool> updateOrderStatus({
  required String orderId,
  required String newStatus, // "Accepted" or "Rejected"
  required String authToken,
}) async {
  try {
    final apiService = ApiService();
    final response = await apiService.post(
      "/api/orders/$orderId/change-status/",
      data: {"status": newStatus},
    );

    return response.statusCode == 200;
  } catch (e) {
    debugPrint("🔥 ERROR: Failed to update order status: $e");
    return false;
  }
}

Future<bool> updateOrderPayment({
  required String orderId,
  required String paymentStatus,
  required String paymentMethod,
  required String authToken,
}) async {
  try {
    final apiService = ApiService();
    final response = await apiService.patch(
      "/api/orders/$orderId/",
      data: {
        "payment_status": paymentStatus,
        "payment_method": paymentMethod,
      },
    );

    return response.statusCode! >= 200 && response.statusCode! < 300;
  } catch (e) {
    debugPrint('🔥 ERROR: Failed to update payment details: $e');
    return false;
  }
}

Future<bool> cancelOrder({
  required String orderId,
  required String comment,
}) async {
  try {
    final apiService = ApiService();
    final response = await apiService.patch(
      "/api/orders/$orderId/cancel/",
      data: {"comment": comment},
    );

    return response.statusCode! >= 200 && response.statusCode! < 300;
  } catch (e) {
    debugPrint('🔥 ERROR: Failed to cancel order: $e');
    return false;
  }
}

Future<bool> updateDineInOrder({
  required String orderId,
  required String customerId,
  required String deliveryType,
  required List<Map<String, dynamic>> items,
}) async {
  try {
    final payload = {
      'order_id': orderId,
      'customerId': customerId,
      'delivery_type': deliveryType,
      'items': items,
    };

    final apiService = ApiService();
    final response = await apiService.patch(
      '/api/orders/$orderId/',
      data: payload,
    );

    return response.statusCode! >= 200 && response.statusCode! < 300;
  } catch (e) {
    debugPrint('🔥 ERROR: Failed to update dine-in order: $e');
    return false;
  }
}

Future<void> createManualOrder({
  required String customerId,
  String? addressId,
  required String deliveryType,
  required String manualOrderMedium,
  required String paymentMethod,
  required String paymentStatus,
  required List<Map<String, dynamic>> items,
  String? comments,
}) async {
  final payload = {
    "customer_id": customerId,
    "delivery_type": deliveryType,
    "manual_order_medium": manualOrderMedium,
    "payment_method": paymentMethod,
    "payment_status": paymentStatus,
    "items": items,
  };

  if (comments != null && comments.isNotEmpty) {
    payload["comments"] = comments;
  }
  if (addressId != null && addressId.isNotEmpty) {
    payload["address_id"] = addressId;
  }

  try {
    final apiService = ApiService();
    await apiService.post(
      "/api/outlets/orders/create/",
      data: payload,
    );
  } catch (e) {
    if (e is DioException) {
      throw Exception(
        'Failed to create order: ${e.response?.statusCode} ${e.message} - ${e.response?.data}',
      );
    }
    rethrow;
  }
}

class ManualOrderQuote {
  const ManualOrderQuote({
    required this.grossTotal,
    required this.taxableValue,
    required this.gstFood,
    required this.gstDelivery,
    required this.gstTotal,
    required this.deliveryCharges,
    required this.discountAmount,
    required this.netTotal,
    required this.grandTotal,
    this.offer,
    this.items = const [],
  });

  final double grossTotal;
  final double taxableValue;
  final double gstFood;
  final double gstDelivery;
  final double gstTotal;
  final double deliveryCharges;
  final double discountAmount;
  final double netTotal;
  final double grandTotal;
  final ManualOrderQuoteOffer? offer;
  final List<ManualOrderQuoteLine> items;

  factory ManualOrderQuote.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    final totalsRaw = json['totals'];
    final totals = totalsRaw is Map<String, dynamic> ? totalsRaw : json;
    final offerMap = json['offer'];

    return ManualOrderQuote(
      grossTotal: _toDouble(totals['gross_total']),
      taxableValue: _toDouble(totals['taxable_value']),
      gstFood: _toDouble(totals['gst_food']),
      gstDelivery: _toDouble(totals['gst_delivery']),
      gstTotal: _toDouble(totals['gst_total']),
      deliveryCharges: _toDouble(totals['delivery_charges']),
      discountAmount: _toDouble(totals['discount_amount']),
      netTotal: _toDouble(totals['net_total']),
      grandTotal: _toDouble(totals['grand_total'] ?? totals['net_total']),
      offer: offerMap is Map<String, dynamic>
          ? ManualOrderQuoteOffer.fromJson(offerMap)
          : null,
      items: (json['items'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ManualOrderQuoteLine.fromJson)
              .toList() ??
          const [],
    );
  }
}

class ManualOrderQuoteLine {
  const ManualOrderQuoteLine({
    required this.productId,
    required this.productName,
    this.variantId,
    this.variantName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.lineTotalAfterDiscount,
    required this.discount,
    this.customizations = const [],
  });

  final String productId;
  final String productName;
  final String? variantId;
  final String? variantName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final double lineTotalAfterDiscount;
  final double discount;
  final List<Map<String, dynamic>> customizations;

  factory ManualOrderQuoteLine.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    int _toInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    String _string(dynamic value) {
      if (value == null) return '';
      return value.toString();
    }

    return ManualOrderQuoteLine(
      productId: _string(json['product_id']),
      productName: _string(json['product_name']),
      variantId: json['variant_id']?.toString(),
      variantName: json['variant_name']?.toString(),
      quantity: _toInt(json['quantity']),
      unitPrice: _toDouble(json['unit_price']),
      lineTotal: _toDouble(json['line_total']),
      lineTotalAfterDiscount:
          _toDouble(json['line_total_after_discount'] ?? json['line_total']),
      discount: _toDouble(json['discount']),
      customizations: (json['customizations'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const [],
    );
  }
}

class ManualOrderQuoteOffer {
  const ManualOrderQuoteOffer({
    required this.campaignId,
    required this.name,
    required this.description,
    required this.discountAmount,
  });

  final String? campaignId;
  final String? name;
  final String? description;
  final double discountAmount;

  factory ManualOrderQuoteOffer.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    String? _string(dynamic value) {
      if (value == null) return null;
      final str = value.toString().trim();
      return str.isEmpty ? null : str;
    }

    return ManualOrderQuoteOffer(
      campaignId: _string(json['campaign_id']),
      name: _string(json['name']),
      description: _string(json['description']),
      discountAmount: _toDouble(json['discount_amount']),
    );
  }
}

Future<ManualOrderQuote> fetchManualOrderQuote({
  required String customerId,
  String? addressId,
  required String deliveryType,
  String? manualOrderMedium,
  String? paymentMethod,
  String? comments,
  required List<Map<String, dynamic>> items,
}) async {
  final payload = <String, dynamic>{
    'customer_id': customerId,
    'delivery_type': deliveryType,
    'items': items,
  };

  if (addressId != null && addressId.isNotEmpty) {
    payload['address_id'] = addressId;
  }

  if (manualOrderMedium != null && manualOrderMedium.isNotEmpty) {
    payload['manual_order_medium'] = manualOrderMedium;
  }

  if (paymentMethod != null && paymentMethod.isNotEmpty) {
    payload['payment_method'] = paymentMethod;
  }

  if (comments != null && comments.isNotEmpty) {
    payload['comments'] = comments;
  }

  debugPrint('📋 Order Quote Request: $payload');

  try {
    final apiService = ApiService();
    final response = await apiService.post(
      "/api/orders/quote/",
      data: payload,
    );

    debugPrint('✅ Order Quote Response: ${response.data}');

    final decoded = response.data;

    if (decoded is Map<String, dynamic>) {
      return ManualOrderQuote.fromJson(decoded);
    }

    throw Exception('Unexpected quote payload format');
  } catch (e) {
    if (e is DioException) {
      throw Exception(
        'Failed to fetch order quote: ${e.response?.statusCode} ${e.message} - ${e.response?.data}',
      );
    }
    rethrow;
  }
}
