import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_service.dart';

/// ✅ Fetch categories
final categoriesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    print('🔵 [categoriesProvider] Starting to fetch categories...');
    final apiService = ApiService();
    final response = await apiService.get('/api/categories/');

    print('[categoriesProvider] Response status: ${response.statusCode}');
    print('[categoriesProvider] Response data type: ${response.data.runtimeType}');

    if (response.statusCode == 200) {
      List<dynamic> data = response.data;
      print('[categoriesProvider] Raw categories count: ${data.length}');
      print('[categoriesProvider] First category (if exists): ${data.isNotEmpty ? data[0] : "No categories"}');

      // Filter only active categories
      final activeCategories = data.where((category) {
        final status = category["status"]?.toString().toLowerCase();
        return status == "active";
      }).toList();

      print('[categoriesProvider] Active categories count: ${activeCategories.length}');

      final result = activeCategories
          .map((category) => {
                "category_id": category["category_id"],
                "name": category["name"],
              })
          .toList();
      print('[categoriesProvider] Mapped categories: $result');
      return result;
    } else {
      throw Exception("Failed to fetch categories");
    }
  } catch (e) {
    print('[categoriesProvider] Error: $e');
    if (e is DioException) {
      print('[categoriesProvider] DioException status: ${e.response?.statusCode}');
      print('[categoriesProvider] DioException data: ${e.response?.data}');
      throw Exception(
        'Failed to fetch categories: ${e.response?.statusCode} ${e.message}',
      );
    }
    rethrow;
  }
});

/// ✅ Fetch product details (for editing mode)
final fetchProductDetailsProvider = FutureProvider.family
    .autoDispose<Map<String, dynamic>, String>((ref, productId) async {
  try {
    final apiService = ApiService();
    final response = await apiService.get('/api/products/$productId/edit-detail/');

    if (response.statusCode == 200) {
      return response.data as Map<String, dynamic>;
    } else {
      throw Exception("Failed to load product details");
    }
  } catch (e) {
    if (e is DioException) {
      throw Exception(
        'Failed to load product details: ${e.response?.statusCode} ${e.message}',
      );
    }
    rethrow;
  }
});

/// ✅ Manage form state using Riverpod
final menuItemStateProvider =
    StateNotifierProvider.autoDispose<MenuItemNotifier, Map<String, dynamic>>(
        (ref) {
  final notifier = MenuItemNotifier();

  // // Reset the state when the provider is disposed
  // ref.onDispose(() {
  //   notifier.reset();
  // });

  return notifier;
});

class MenuItemNotifier extends StateNotifier<Map<String, dynamic>> {
  MenuItemNotifier()
      : super({
          "display_image": "",
          "name": "",
          "description": "",
          "size": "",
          "price": "",
          "stock": "",
          "preparationTime": "",
          "additionalTime": "",
          "itemsIncluded": "",
          "selectedCategory": null,
          "isActive": true,
          "customizable": false,
        });

  void updateField(String key, dynamic value) {
    state = {...state, key: value};
  }

  void reset() {
    state = {
      "display_image": "",
      "name": "",
      "description": "",
      "size": "",
      "price": "",
      "stock": "",
      "preparationTime": "",
      "additionalTime": "",
      "itemsIncluded": "",
      "selectedCategory": null,
      "isActive": true,
      "customizable": false,
    };
  }
}
