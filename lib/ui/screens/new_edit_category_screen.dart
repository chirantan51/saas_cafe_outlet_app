import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:outlet_app/core/utils/url_utils.dart';
import 'package:outlet_app/providers/menu_item_provider.dart';
import 'package:dio/dio.dart';

import '../../providers/category_provider.dart';
import '../../core/api_service.dart';
import '../widgets/action_button.dart';

class NewEditCategoryScreen extends ConsumerStatefulWidget {
  final bool isEditMode;
  final String? categoryId;

  const NewEditCategoryScreen(
      {Key? key, required this.isEditMode, this.categoryId})
      : super(key: key);

  @override
  _NewEditCategoryScreenState createState() => _NewEditCategoryScreenState();
}

class _NewEditCategoryScreenState extends ConsumerState<NewEditCategoryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false; // ✅ Added to show loading indicator

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode && widget.categoryId != null) {
      _fetchCategoryDetails();
    }
  }

  /// ✅ Fetch Category Details & Pre-fill form
  Future<void> _fetchCategoryDetails() async {
    setState(() => _isLoading = true);
    final categoryAsync =
        ref.read(fetchCategoryDetailsProvider(widget.categoryId!).future);

    try {
      final category = await categoryAsync;
      ref
          .read(categoryStateProvider.notifier)
          .updateField("name", category["name"]);
      ref
          .read(categoryStateProvider.notifier)
          .updateField("description", category["description"]);
      ref
          .read(categoryStateProvider.notifier)
          .updateField("display_image", category["display_image"]);
      ref
          .read(categoryStateProvider.notifier)
          .updateField("status", category["status"]);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load category details")),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _uploadCategoryImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return; // User canceled image selection

    try {
      final apiService = ApiService();
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          pickedFile.path,
          filename: pickedFile.path.split('/').last,
        ),
      });

      final response = await apiService.post(
        '/api/categories/upload_image/',
        data: formData,
      );

      if (response.statusCode == 201) {
        String uploadedImageUrl = response.data["display_image"];

        print("Category image uploaded at: $uploadedImageUrl");
        ref
            .read(categoryStateProvider.notifier)
            .updateField("display_image", uploadedImageUrl);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Image uploaded successfully!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to upload image")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to upload image: $e")),
      );
    }
  }

  /// ✅ Save Product (Create or Update)
  Future<void> _saveCategory2(BuildContext context, WidgetRef ref) async {
    // ✅ Check if the form is valid before sending API request
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final state = ref.read(categoryStateProvider);

    try {
      final apiService = ApiService();
      final isUpdate = state["category_id"] != null;
      final endpoint = isUpdate
          ? '/api/categories/${state["category_id"]}/'
          : '/api/categories/';

      debugPrint("🟢 DEBUG: Sending API request to $endpoint");

      final response = isUpdate
          ? await apiService.put(
              endpoint,
              data: {
                "name": state["name"],
                "description": state["description"],
                "status": state["status"],
                "display_image": state["display_image"],
              },
            )
          : await apiService.post(
              endpoint,
              data: {
                "name": state["name"],
                "description": state["description"],
                "status": state["status"],
                "display_image": state["display_image"],
              },
            );

      debugPrint("🔵 DEBUG: Response Code = ${response.statusCode}");
      debugPrint("🔵 DEBUG: Response Body = ${response.data}");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Category ${state["name"]} ${isUpdate ? 'updated' : 'created'}..")));
      // ✅ Refresh category list after save
      ref.invalidate(categoriesProvider);
      Navigator.pop(context, true);
    } catch (error, stacktrace) {
      debugPrint("🔥 ERROR: Exception in category saving: $error");
      debugPrint("📌 STACKTRACE: $stacktrace");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save category")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryState = ref.watch(categoryStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditMode ? "Edit Category" : "New Category"),
        elevation: 1,
        shadowColor: Colors.black26,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator()) // ✅ Show loading indicator
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // ✅ Image Upload Section
                    InkWell(
                      onTap: _uploadCategoryImage,
                      child: Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Center(
                          child: () {
                            final imageUrl = resolveMediaUrl(
                                categoryState["display_image"] as String?);
                            if (imageUrl == null) {
                              return const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt,
                                      size: 50, color: Colors.grey),
                                  Text("Upload Category Image",
                                      style: TextStyle(color: Colors.grey)),
                                ],
                              );
                            }
                            return Image.network(imageUrl, fit: BoxFit.cover);
                          }(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ✅ Name Field
                    TextFormField(
                      decoration:
                          const InputDecoration(labelText: "Category Name"),
                      initialValue: categoryState["name"],
                      validator: (value) =>
                          value!.isEmpty ? "Please enter category name" : null,
                      onChanged: (value) => ref
                          .read(categoryStateProvider.notifier)
                          .updateField("name", value),
                    ),

                    const SizedBox(height: 10),

                    // ✅ Description Field
                    TextFormField(
                      decoration:
                          const InputDecoration(labelText: "Description"),
                      initialValue: categoryState["description"],
                      validator: (value) =>
                          value!.isEmpty ? "Please enter description" : null,
                      onChanged: (value) => ref
                          .read(categoryStateProvider.notifier)
                          .updateField("description", value),
                    ),

                    const SizedBox(height: 10),

                    // ✅ Status Toggle
                    SwitchListTile(
                      title: const Text("Active Status"),
                      value: categoryState["status"] == "Active" ? true : false,
                      onChanged: (value) => ref
                          .read(categoryStateProvider.notifier)
                          .updateField(
                              "status", value == true ? "Active" : "Inactive"),
                    ),

                    const SizedBox(height: 20),

                    // ✅ Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ActionButton(
                        onPressed: () => _saveCategory2(context, ref),
                        label: widget.isEditMode ? "Update" : "Save",
                        icon: widget.isEditMode ? Icons.save : Icons.check,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
