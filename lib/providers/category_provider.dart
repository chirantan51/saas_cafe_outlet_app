import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_service.dart';
import '../providers/menu_item_provider.dart';

/// ✅ Fetch a single category for editing
final fetchCategoryDetailsProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, categoryId) async {
  try {
    final apiService = ApiService();
    final response = await apiService.get('/api/categories/$categoryId/');

    if (response.statusCode == 200) {
      return response.data as Map<String, dynamic>;
    } else {
      throw Exception("Failed to load category details");
    }
  } catch (e) {
    if (e is DioException) {
      throw Exception(
        'Failed to load category details: ${e.response?.statusCode} ${e.message}',
      );
    }
    rethrow;
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
  try {
    final apiService = ApiService();
    final String endpoint = categoryData["category_id"] == null
        ? "/api/categories/" // ✅ Create
        : "/api/categories/${categoryData["category_id"]}/"; // ✅ Update

    debugPrint("🟢 DEBUG: Sending API request to $endpoint");

    final payload = {
      "name": categoryData["name"],
      "description": categoryData["description"],
      "status": categoryData["status"],
      "display_image": categoryData["display_image"],
    };

    final response = categoryData["category_id"] == null
        ? await apiService.post(endpoint, data: payload)
        : await apiService.put(endpoint, data: payload);

    debugPrint("🔵 DEBUG: Response Code = ${response.statusCode}");
    debugPrint("🔵 DEBUG: Response Body = ${response.data}");

    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint(
          "🔥 ERROR: Failed to save category. Response: ${response.data}");
      throw Exception("Failed to save category");
    }

    // ✅ Refresh category list after save
    ref.invalidate(categoriesProvider);
  } catch (error, stacktrace) {
    if (error is DioException) {
      debugPrint("🔥 ERROR: DioException in category saving: ${error.response?.statusCode} ${error.message}");
      throw Exception(
        'Failed to save category: ${error.response?.statusCode} ${error.message}',
      );
    }
    debugPrint("🔥 ERROR: Exception in category saving: $error");
    debugPrint("📌 STACKTRACE: $stacktrace");
    rethrow;
  }
});

/// ✅ Delete Category
final deleteCategoryProvider =
    FutureProvider.family<void, String>((ref, categoryId) async {
  try {
    final apiService = ApiService();
    final response = await apiService.delete("/api/categories/$categoryId/");

    if (response.statusCode != 204 && response.statusCode != 200) {
      String errorMsg = 'Failed to delete category';
      final errData = response.data;
      if (errData is Map && errData['detail'] is String) {
        errorMsg = errData['detail'];
      }
      throw Exception(errorMsg);
    }

    // ✅ Refresh category list after deletion
    ref.invalidate(categoriesProvider);
  } catch (e) {
    if (e is DioException) {
      String errorMsg = 'Failed to delete category';
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
});
