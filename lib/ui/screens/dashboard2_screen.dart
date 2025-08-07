import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:outlet_app/constants.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

final dashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString("auth_token");
  if (token == null) throw Exception("Auth token missing");

  final response = await http.get(
    Uri.parse("$BASE_URL/api/outlets/dashboard/"),
    headers: {
      "Authorization": "Token $token",
      "Content-Type": "application/json",
    },
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception("Failed to fetch dashboard data");
  }
});

class DashboardScreen2 extends ConsumerWidget {
  const DashboardScreen2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF1F0F5),
      body: dashboard.when(
        data: (data) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _dashboardCard("Today's Orders", data["total_orders"].toString(), Colors.blue),
              _dashboardCard("Total Revenue", "₹${data["total_revenue"]}", Colors.green),
              _dashboardCard("Pending Orders", data["pending_orders"].toString(), Colors.orange),
              _dashboardCard("Cancelled Orders", data["cancelled_orders"].toString(), Colors.red),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Widget _dashboardCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
