import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:outlet_app/constants.dart';
import 'package:http/http.dart' as http;

Future<bool> updateOrderStatus({
  required String orderId,
  required String newStatus, // "Accepted" or "Rejected"
  required String authToken,
}) async {
  final url = Uri.parse("$BASE_URL/api/orders/$orderId/change-status/");

  final response = await http.post(
    url,
    headers: {
      "Authorization": "Token $authToken",
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "status": newStatus,
    }),
  );
  if (response.statusCode != 200) {
    debugPrint("🔥 ERROR: Failed to update order status: ${response.body}");
    return false;
  }
  return response.statusCode == 200;
}
