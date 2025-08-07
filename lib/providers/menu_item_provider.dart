import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:outlet_app/constants.dart'; // BASE_URL
import 'package:shared_preferences/shared_preferences.dart';

/// ✅ Fetch categories
final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  String? authToken = prefs.getString("auth_token");

  if (authToken == null) throw Exception("No authentication token found");

  final response = await http.get(
    Uri.parse("$BASE_URL/api/categories/"),
    headers: {"Authorization": "Token $authToken"},
  );

  if (response.statusCode == 200) {
    List<dynamic> data = jsonDecode(response.body);
    return data.map((category) => {
      "category_id": category["category_id"],
      "name": category["name"],
    }).toList();
  } else {
    throw Exception("Failed to fetch categories");
  }
});

/// ✅ Fetch product details (for editing mode)
final fetchProductDetailsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, productId) async {
  final prefs = await SharedPreferences.getInstance();
  String? authToken = prefs.getString("auth_token");

  if (authToken == null) throw Exception("No authentication token found");

  final response = await http.get(
    Uri.parse("$BASE_URL/api/products/$productId/"),
    headers: {"Authorization": "Token $authToken"},
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception("Failed to load product details");
  }
});

/// ✅ Manage form state using Riverpod
final menuItemStateProvider = StateNotifierProvider.autoDispose<MenuItemNotifier, Map<String, dynamic>>((ref) {
  final notifier = MenuItemNotifier();

  // // Reset the state when the provider is disposed
  // ref.onDispose(() {
  //   notifier.reset();
  // });

  return notifier;
});

class MenuItemNotifier extends StateNotifier<Map<String, dynamic>> {
  MenuItemNotifier() : super({
    "display_image": "",
    "name": "",
    "description": "",
    "size": "",
    "price": "",
    "selectedCategory": null,
    "isActive": true,
  });

  void updateField(String key, dynamic value) {
    state = {...state, key: value};
  }

  void reset() {
    state = {
      "display_image":"",
      "name": "",
      "description": "",
      "size": "",
      "price": "",
      "selectedCategory": null,
      "isActive": true,
    };
  }
}
