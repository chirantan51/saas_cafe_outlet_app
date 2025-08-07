import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:outlet_app/constants.dart'; // BASE_URL
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/menu_item_provider.dart';

/// ✅ Fetch a single category for editing
final fetchCategoryDetailsProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, categoryId) async {
  final prefs = await SharedPreferences.getInstance();
  String? authToken = prefs.getString("auth_token");

  if (authToken == null) throw Exception("No authentication token found");

  final response = await http.get(
    Uri.parse("$BASE_URL/api/categories/$categoryId/"),
    headers: {"Authorization": "Token $authToken"},
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception("Failed to load category details");
  }
});

/// ✅ State Provider for Category Form
final categoryStateProvider =
    StateNotifierProvider<CategoryNotifier, Map<String, dynamic>>((ref) {
  final notifier = CategoryNotifier();

  // Reset the state when the provider is disposed
  ref.onDispose(() {
    notifier.reset();
  });

  return notifier;
});

class CategoryNotifier extends StateNotifier<Map<String, dynamic>> {
  CategoryNotifier()
      : super({
          "display_image": "",
          "name": "",
          "description": "",
          "status": "Active",
        });

  void updateField(String key, dynamic value) {
    if (key == "status" && value is! String) {
      debugPrint("🚨 ERROR: status must be a String ('Active' or 'Inactive')");
      return;
    }
    state = {...state, key: value};
  }

  void reset() {
    state = {
      "display_image": "",
      "name": "",
      "description": "",
      "status": "Active",
    };
  }
}

/// ✅ Create or Update Category
final createOrUpdateCategoryProvider =
    FutureProvider.family<void, Map<String, dynamic>>(
        (ref, categoryData) async {
  final prefs = await SharedPreferences.getInstance();
  String? authToken = prefs.getString("auth_token");

  if (authToken == null) {
    debugPrint("🔥 ERROR: No authentication token found");
    throw Exception("No authentication token found");
  }

  try {
    final String url = categoryData["category_id"] == null
        ? "$BASE_URL/api/categories/" // ✅ Create
        : "$BASE_URL/api/categories/${categoryData["category_id"]}/"; // ✅ Update

    final requestMethod =
        categoryData["category_id"] == null ? http.post : http.put;

    debugPrint("🟢 DEBUG: Sending API request to $url");

    final response = await requestMethod(
      Uri.parse(url),
      headers: {
        "Authorization": "Token $authToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "name": categoryData["name"],
        "description": categoryData["description"],
        "status": categoryData["status"],
        "display_image": categoryData["display_image"],
      }),
    );

    debugPrint("🔵 DEBUG: Response Code = ${response.statusCode}");
    debugPrint("🔵 DEBUG: Response Body = ${response.body}");

    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint(
          "🔥 ERROR: Failed to save category. Response: ${response.body}");
      throw Exception("Failed to save category");
    }

    // ✅ Refresh category list after save
    ref.invalidate(categoriesProvider);
  } catch (error, stacktrace) {
    debugPrint("🔥 ERROR: Exception in category saving: $error");
    debugPrint("📌 STACKTRACE: $stacktrace");
    throw Exception("An error occurred while saving the category");
  }
});

/// ✅ Delete Category
final deleteCategoryProvider =
    FutureProvider.family<void, String>((ref, categoryId) async {
  final prefs = await SharedPreferences.getInstance();
  String? authToken = prefs.getString("auth_token");

  if (authToken == null) throw Exception("No authentication token found");

  final response = await http.delete(
    Uri.parse("$BASE_URL/api/categories/$categoryId/"),
    headers: {"Authorization": "Token $authToken"},
  );

  if (response.statusCode != 204) {
    throw Exception("Failed to delete category");
  }

  // ✅ Refresh category list after deletion
  ref.invalidate(categoriesProvider);
});
