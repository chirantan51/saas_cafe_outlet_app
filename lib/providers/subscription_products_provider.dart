import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class SubscriptionOrderLite {
  final String orderId;
  final String status;
  final String customerName;
  final String customerMobile;
  final double grossTotal;
  final String? deliveryAddress;
  final DateTime placedAt;
  final DateTime? approxDeliveryTime;

  SubscriptionOrderLite({
    required this.orderId,
    required this.status,
    required this.customerName,
    required this.customerMobile,
    required this.grossTotal,
    required this.deliveryAddress,
    required this.placedAt,
    required this.approxDeliveryTime,
  });

  factory SubscriptionOrderLite.fromJson(Map<String, dynamic> j) => SubscriptionOrderLite(
        orderId: j['order_id'],
        status: j['status'],
        customerName: j['customer_name'] ?? '',
        customerMobile: j['customer_mobile'] ?? '',
        grossTotal: double.tryParse(j['gross_total'].toString()) ?? 0.0,
        deliveryAddress: j['delivery_address'],
        placedAt: DateTime.parse(j['placed_at']),
        approxDeliveryTime: (() {
          final v = j['approx_delivery_time'];
          if (v == null) return null;
          return DateTime.tryParse(v.toString());
        })(),
      );
}

class SubscriptionSlot {
  final String label;
  final DateTime start;
  final int orderCount;
  final List<SubscriptionOrderLite> orders;

  SubscriptionSlot({
    required this.label,
    required this.start,
    required this.orderCount,
    required this.orders,
  });

  factory SubscriptionSlot.fromJson(Map<String, dynamic> j) => SubscriptionSlot(
        label: j['label'] ?? '',
        start: DateTime.parse(j['start']),
        orderCount: (j['orderCount'] as num?)?.toInt() ?? 0,
        orders: (j['orders'] as List<dynamic>? ?? const [])
            .map((e) => SubscriptionOrderLite.fromJson(e))
            .toList(),
      );
}

class SubscriptionProduct {
  final String productId;
  final String name;
  final String? image;
  final String? size;
  final int totalOrderCount;
  final int slotCount;
  final List<SubscriptionSlot> slots;

  SubscriptionProduct({
    required this.productId,
    required this.name,
    this.image,
    this.size,
    required this.totalOrderCount,
    required this.slotCount,
    required this.slots,
  });

  factory SubscriptionProduct.fromJson(Map<String, dynamic> j) => SubscriptionProduct(
        productId: j['productId'],
        name: j['name'] ?? '',
        image: j['image'],
        size: j['size'],
        totalOrderCount: (j['totals']?['orderCount'] as num?)?.toInt() ?? 0,
        slotCount: (j['totals']?['slotCount'] as num?)?.toInt() ?? 0,
        slots: (j['slots'] as List<dynamic>? ?? const [])
            .map((e) => SubscriptionSlot.fromJson(e))
            .toList(),
      );
}

class SubscriptionDashboardMeta {
  final String date;
  final String outletId;
  final int productCount;
  final int orderCount;
  SubscriptionDashboardMeta({
    required this.date,
    required this.outletId,
    required this.productCount,
    required this.orderCount,
  });
  factory SubscriptionDashboardMeta.fromJson(Map<String, dynamic> j) => SubscriptionDashboardMeta(
        date: j['date'] ?? '',
        outletId: j['outletId'] ?? '',
        productCount: (j['productCount'] as num?)?.toInt() ?? 0,
        orderCount: (j['orderCount'] as num?)?.toInt() ?? 0,
      );
}

class SubscriptionDashboard {
  final SubscriptionDashboardMeta meta;
  final List<SubscriptionProduct> products;
  SubscriptionDashboard({required this.meta, required this.products});
  factory SubscriptionDashboard.fromJson(Map<String, dynamic> j) => SubscriptionDashboard(
        meta: SubscriptionDashboardMeta.fromJson(j['meta'] ?? const {}),
        products: (j['data']?['products'] as List<dynamic>? ?? const [])
            .map((e) => SubscriptionProduct.fromJson(e))
            .toList(),
      );
}

final subscriptionDashboardProvider =
    FutureProvider<SubscriptionDashboard>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  if (token == null) throw Exception('Not authenticated');
  final resp = await http.get(
    Uri.parse("$BASE_URL/api/orders/dashboard-orders-subscription/"),
    headers: {
      'Authorization': 'Token $token',
      'Content-Type': 'application/json',
    },
  );
  if (resp.statusCode == 200) {
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return SubscriptionDashboard.fromJson(json);
  } else {
    throw Exception('Failed to load subscription dashboard');
  }
});

