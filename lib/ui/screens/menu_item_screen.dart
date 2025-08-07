import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outlet_app/constants.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/menu_item_provider.dart';
import '../../providers/menu_provider.dart';

class MenuItemScreen extends ConsumerStatefulWidget {
  final bool isEditMode;
  final String? productId;

  const MenuItemScreen({Key? key, required this.isEditMode, this.productId})
      : super(key: key);

  @override
  _MenuItemScreenState createState() => _MenuItemScreenState();
}

class _MenuItemScreenState extends ConsumerState<MenuItemScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // ✅ Add controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // ✅ Reset the state before fetching data
    Future.microtask(() {
      ref.read(menuItemStateProvider.notifier).reset();

      if (widget.isEditMode && widget.productId != null) {
        _fetchProductDetails();
      }
    });

    // if (widget.isEditMode && widget.productId != null) {
    //   _fetchProductDetails();
    // }
  }

  @override
  void dispose() {
    // ✅ Dispose controllers to avoid memory leaks
    _nameController.dispose();
    _descriptionController.dispose();
    _sizeController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  /// ✅ Fetch Product Details & Update State
  Future<void> _fetchProductDetails() async {
    final productAsync =
        ref.read(fetchProductDetailsProvider(widget.productId!).future);

    try {
      final product = await productAsync;

      // ✅ Update state safely after the widget has built
      if (mounted) {
        ref
            .read(menuItemStateProvider.notifier)
            .updateField("name", product["name"]);
        ref
            .read(menuItemStateProvider.notifier)
            .updateField("description", product["description"]);
        ref
            .read(menuItemStateProvider.notifier)
            .updateField("size", product["size"]);
        ref
            .read(menuItemStateProvider.notifier)
            .updateField("price", product["price"]);
        final category = product["category"];
        ref
            .read(menuItemStateProvider.notifier)
            .updateField("selectedCategory", category["category_id"]);
        ref
            .read(menuItemStateProvider.notifier)
            .updateField("isActive", product["status"] == "Active");
        ref
            .read(menuItemStateProvider.notifier)
            .updateField("display_image", product["display_image"]);

        // ✅ Update controllers with fetched data
        print("[dkC] Product: $product");
        _nameController.text = product["name"];
        _descriptionController.text = product["description"];
        _sizeController.text = product["size"];
        _priceController.text = product["price"];

      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load product details")),
        );
      }
    }
  }

  /// ✅ Save Product (Create or Update)
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final state = ref.read(menuItemStateProvider);
    final prefs = await SharedPreferences.getInstance();
    String? authToken = prefs.getString("auth_token");

    if (authToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Authentication failed")),
      );
      return;
    }

    final url = widget.isEditMode
        ? "$BASE_URL/api/products/${widget.productId}/"
        : "$BASE_URL/api/products/";

    final request = widget.isEditMode ? http.put : http.post;

    final response = await request(
      Uri.parse(url),
      headers: {
        "Authorization": "Token $authToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "name": state["name"],
        "description": state["description"],
        "size": state["size"],
        "price": state["price"],
        "category_id": state["selectedCategory"],
        "status": state["isActive"] ? "Active" : "Inactive",
        "display_image": state["display_image"],
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isEditMode
            ? "Item updated successfully"
            : "Item added successfully"),
      ));

      ref.invalidate(menuItemStateProvider); // ✅ Reset the provider state
      ref.read(menuProvider.notifier).fetchMenuData();
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Failed to save item")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuState = ref.watch(menuItemStateProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    // ✅ Use ref.watch to react to state changes
    ref.watch(menuItemStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditMode ? "Edit Item" : "Add Item"),
        backgroundColor: const Color(0xFF54A079),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ✅ Image Upload Section
              InkWell(
                onTap: () async {
                  await _uploadProductImage(context, ref);
                },
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Center(
                    child: menuState["display_image"] != null &&
                            menuState["display_image"].isNotEmpty
                        ? Image.network(
                            "$BASE_URL${menuState["display_image"]}",
                            fit: BoxFit.cover)
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt,
                                  size: 50, color: Colors.grey),
                              Text("Upload Item Image",
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ✅ Name Field
              TextFormField(
                decoration: const InputDecoration(labelText: "Item Name"),
                controller: _nameController,
                validator: (value) =>
                    value!.isEmpty ? "Please enter item name" : null,
                onChanged: (value) => ref
                    .read(menuItemStateProvider.notifier)
                    .updateField("name", value),
              ),

              const SizedBox(height: 10),

              // ✅ Description Field
              TextFormField(
                decoration: const InputDecoration(labelText: "Description"),
                controller: _descriptionController,
                validator: (value) =>
                    value!.isEmpty ? "Please enter description" : null,
                onChanged: (value) => ref
                    .read(menuItemStateProvider.notifier)
                    .updateField("description", value),
              ),

              const SizedBox(height: 10),

              // ✅ Size & Price Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: "Size"),
                      controller: _sizeController,
                      validator: (value) =>
                          value!.isEmpty ? "Please enter size" : null,
                      onChanged: (value) => ref
                          .read(menuItemStateProvider.notifier)
                          .updateField("size", value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Price (₹)"),
                      controller: _priceController,
                      validator: (value) =>
                          value!.isEmpty ? "Please enter price" : null,
                      onChanged: (value) => ref
                          .read(menuItemStateProvider.notifier)
                          .updateField("price", value),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ✅ Category Dropdown
              categoriesAsync.when(
                data: (categories) {
                  // ✅ Debug: Print the selected category from state
                  print("[dkC] Dropdown Value: ${menuState["selectedCategory"]}");

                  // ✅ Ensure categories are loaded and not empty
                  if (categories.isEmpty) {
                    return const Text("No categories available");
                  }

                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Category"),
                    value: menuState["selectedCategory"],
                    items: categories.map<DropdownMenuItem<String>>((category) {
                      return DropdownMenuItem<String>(
                        value: category["category_id"],
                        child: Text(category["name"]),
                      );
                    }).toList(),
                    onChanged: (value) => ref
                        .read(menuItemStateProvider.notifier)
                        .updateField("selectedCategory", value),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => const Text("Error loading categories"),
              ),

              const SizedBox(height: 10),

              // ✅ Status Toggle
              SwitchListTile(
                title: const Text("Active Status"),
                value: menuState["isActive"],
                onChanged: (value) => ref
                    .read(menuItemStateProvider.notifier)
                    .updateField("isActive", value),
              ),

              const SizedBox(height: 20),

              // ✅ Save Button
              ElevatedButton(
                onPressed: _saveProduct,
                child: Text(widget.isEditMode ? "Update" : "Save"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ Upload Product Image Separately
  Future<void> _uploadProductImage(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final prefs = await SharedPreferences.getInstance();
    String? authToken = prefs.getString("auth_token");

    if (authToken == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Authentication failed")));
      return;
    }

    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return; // User canceled image selection

    File imageFile = File(pickedFile.path);

    var request = http.MultipartRequest(
      "POST",
      Uri.parse(
          "$BASE_URL/api/products/upload_image/"), // ✅ Upload without productId
    );

    request.headers["Authorization"] = "Token $authToken";
    request.files
        .add(await http.MultipartFile.fromPath("image", imageFile.path));

    var response = await request.send();
    var responseData = await response.stream.bytesToString();

    if (response.statusCode == 201) {
      final responseBody = jsonDecode(responseData);
      String uploadedImageUrl =
          responseBody["display_image"]; // ✅ Get the uploaded image URL

      print("dkC Image uploaded at: $uploadedImageUrl");
      // ✅ Store uploaded image URL in state
      ref
          .read(menuItemStateProvider.notifier)
          .updateField("display_image", uploadedImageUrl);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Image uploaded successfully!"),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Failed to upload image"),
      ));
    }
  }
}
