import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/order_model.dart';
import '../constants.dart';

final recentOrdersProvider =
    FutureProvider<List<OrderModel>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');

  if (token == null) throw Exception("Not authenticated");

  final response = await http.get(
    Uri.parse("$BASE_URL/api/orders/recent-orders/"),
    headers: {
      'Authorization': 'Token $token',
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    final List decoded = jsonDecode(response.body);
    return decoded.map((json) => OrderModel.fromJson(json)).toList();
  } else {
    throw Exception("Failed to load recent orders");
  }
});
