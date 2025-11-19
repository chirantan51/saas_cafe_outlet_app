import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../constants.dart'; // BASE_URL

/// ✅ **State Model for Menu**
class MenuState {
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> filteredItems;
  final String selectedCategoryId;
  final bool isLoading;

  MenuState({
    required this.categories,
    required this.items,
    required this.filteredItems,
    required this.selectedCategoryId,
    required this.isLoading,
  });

  /// ✅ CopyWith for Updating State
  MenuState copyWith({
    List<Map<String, dynamic>>? categories,
    List<Map<String, dynamic>>? items,
    List<Map<String, dynamic>>? filteredItems,
    String? selectedCategoryId,
    bool? isLoading,
  }) {
    return MenuState(
      categories: categories ?? this.categories,
      items: items ?? this.items,
      filteredItems: filteredItems ?? this.filteredItems,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// ✅ **StateNotifier for Managing Menu**
class MenuNotifier extends StateNotifier<MenuState> {
  bool _mounted = true;

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  MenuNotifier()
      : super(MenuState(
          categories: [],
          items: [],
          filteredItems: [],
          selectedCategoryId: "all",
          isLoading: true,
        )) {
    fetchMenuData(); // ✅ Fetch Data on Init
  }

  /// ✅ Fetch Categories & Items from API
  Future<void> fetchMenuData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? authToken = prefs.getString("auth_token");
      if (authToken == null) throw Exception("No authentication token found");

      final response = await http.get(
        Uri.parse("$BASE_URL/api/products/grouped-by-category/"),
        headers: {
          "Authorization": "Token $authToken",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        dynamic data = jsonDecode(response.body);
        if (data == null || data.isEmpty || data is! List) {
          throw Exception("Invalid API Response Format");
        }

        print("Data: $data");

        List<Map<String, dynamic>> loadedCategories = [
          {
            "category_id": "all",
            "name": "All",
            "icon": "",
          }
        ];
        List<Map<String, dynamic>> loadedItems = [];

        for (var category in data) {
          if (category == null || category["category_id"] == null) continue;

          loadedCategories.add({
            "category_id": category["category_id"].toString(),
            "name": category["name"],
            "icon": category["display_image"] ?? "", // ✅ Fetch Icon URL
          });

          if (category.containsKey("products") &&
              category["products"] is List) {
            for (var product in category["products"]) {
              if (product == null) continue;
              print(product);

              final variantsRaw = (product["variants"] as List?)
                      ?.whereType<Map<String, dynamic>>()
                      .map((variant) => {
                            "variant_id": variant["variant_id"],
                            "name": variant["name"],
                            "description": variant["description"],
                            "price": variant["price"],
                            "is_active": variant["is_active"],
                            "slug": variant["slug"],
                          })
                      .toList() ??
                  [];

              loadedItems.add({
                "id": product["product_id"],
                "name": product["name"],
                "price": product["price"],
                "description": product["description"],
                "size": product["size"],
                "customizable": product["customizable"],
                "items_included": product["items_included"],
                "variants": variantsRaw,
                "category_id": category["category_id"],
                "display_image":
                    product["display_image"] ?? "", // ✅ Fetch Image URL
              });
            }
          }
        }

        if (_mounted) {
          state = state.copyWith(
            categories: loadedCategories,
            items: loadedItems,
            filteredItems: loadedItems, // ✅ Default to all items
            isLoading: false,
          );
        }
      } else {
        throw Exception("Failed to load menu data");
      }
    } catch (e) {
      if (_mounted) {
        state = state.copyWith(isLoading: false);
      }
      print("❌ Error: $e");
    }
  }

  /// ✅ Select a Category & Filter Items
  void selectCategory(String categoryId) {
    List<Map<String, dynamic>> filteredList;
    if (categoryId == "all") {
      filteredList = state.items;
    } else {
      filteredList = state.items
          .where((item) => item["category_id"] == categoryId)
          .toList();
    }

    state = state.copyWith(
      selectedCategoryId: categoryId,
      filteredItems: filteredList,
    );
  }

  /// ✅ Delete an Item
  void deleteItem(String itemId) {
    final updatedItems =
        state.items.where((item) => item["id"] != itemId).toList();
    final updatedFilteredItems =
        state.filteredItems.where((item) => item["id"] != itemId).toList();

    state = state.copyWith(
      items: updatedItems,
      filteredItems: updatedFilteredItems,
    );
  }
}

/// ✅ **Riverpod Provider**
final menuProvider = StateNotifierProvider<MenuNotifier, MenuState>(
  (ref) => MenuNotifier(),
);
