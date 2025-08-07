import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';

final dashboardProvider = FutureProvider<DashboardMetrics>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString("auth_token");
  if (token == null) throw Exception("Missing token");

  final res = await http.get(
    Uri.parse('$BASE_URL/api/outlets/dashboard/'),
    headers: {
      'Authorization': 'Token $token',
      'Content-Type': 'application/json',
    },
  );

  if (res.statusCode == 200) {
    return DashboardMetrics.fromJson(jsonDecode(res.body));
  } else {
    throw Exception("Failed to load dashboard metrics");
  }
});

class DashboardMetrics {
  final int totalOrders;
  final double totalRevenue;
  final int pendingOrders;
  final int cancelledOrders;

  DashboardMetrics({
    required this.totalOrders,
    required this.totalRevenue,
    required this.pendingOrders,
    required this.cancelledOrders,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardMetrics(
      totalOrders: json["total_orders"],
      totalRevenue: (json["total_revenue"] as num).toDouble(),
      pendingOrders: json["pending_orders"],
      cancelledOrders: json["cancelled_orders"],
    );
  }
}
