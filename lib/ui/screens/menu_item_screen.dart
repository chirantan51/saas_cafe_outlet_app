import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:outlet_app/constants.dart';
import 'package:outlet_app/core/utils/url_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/menu_item_provider.dart';
import '../../providers/menu_provider.dart';

enum MenuItemLayout { modern, classic }

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
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _prepTimeController = TextEditingController();
  final TextEditingController _additionalTimeController =
      TextEditingController();
  final TextEditingController _itemsIncludedController =
      TextEditingController();
  final List<_VariantFormEntry> _variantForms = [];
  MenuItemLayout _layout = MenuItemLayout.modern;

  @override
  void initState() {
    super.initState();

    _variantForms.add(_VariantFormEntry());

    // ✅ Reset the state before fetching data
    Future.microtask(() {
      ref.read(menuItemStateProvider.notifier).reset();
      _nameController.clear();
      _descriptionController.clear();
      _sizeController.clear();
      _priceController.clear();
      _stockController.clear();
      _prepTimeController.clear();
      _additionalTimeController.clear();
      _itemsIncludedController.clear();

      if (widget.isEditMode && widget.productId != null) {
        ref.invalidate(fetchProductDetailsProvider(widget.productId!));
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
    _stockController.dispose();
    _prepTimeController.dispose();
    _additionalTimeController.dispose();
    _itemsIncludedController.dispose();
    for (final variant in _variantForms) {
      variant.dispose();
    }
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
        final stockValue = product["stock"] ??
            product["initial_stock"] ??
            product["inventory"];
        ref
            .read(menuItemStateProvider.notifier)
            .updateField("stock", stockValue?.toString() ?? "");
        ref.read(menuItemStateProvider.notifier).updateField("preparationTime",
            product["preparation_time_of_first_unit"]?.toString() ?? "");
        ref.read(menuItemStateProvider.notifier).updateField("additionalTime",
            product["additional_time_to_make_excess_units"]?.toString() ?? "");
        final itemsIncluded = (product["items_included"] as List?)
                ?.map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList() ??
            const [];
        ref
            .read(menuItemStateProvider.notifier)
            .updateField("itemsIncluded", itemsIncluded.join('\n'));
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
        ref
            .read(menuItemStateProvider.notifier)
            .updateField("customizable", product["customizable"] == true);

        // ✅ Update controllers with fetched data
        print("[dkC] Product: $product");
        _nameController.text = product["name"];
        _descriptionController.text = product["description"];
        _sizeController.text = product["size"];
        _priceController.text = product["price"];
        _stockController.text = stockValue?.toString() ?? "";
        _prepTimeController.text =
            product["preparation_time_of_first_unit"]?.toString() ?? "";
        _additionalTimeController.text =
            product["additional_time_to_make_excess_units"]?.toString() ?? "";
        _itemsIncludedController.text = itemsIncluded.join('\n');

        final variants = (product["variants_payload"] as List?) ??
            (product["variants"] as List?);
        _setVariantsFromPayload(variants);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load product details")),
        );
      }
    }
  }

  void _setVariantsFromPayload(List? variants) {
    final entries = <_VariantFormEntry>[];
    if (variants != null && variants.isNotEmpty) {
      for (final variant in variants) {
        if (variant is Map<String, dynamic>) {
          entries.add(
            _VariantFormEntry(
              name: variant["name"]?.toString(),
              description: variant["description"]?.toString(),
              price: variant["price"]?.toString(),
              isActive: variant["is_active"] != false,
              variantId: variant['variant_id']?.toString(),
            ),
          );
        }
      }
    }

    if (entries.isEmpty) {
      entries.add(_VariantFormEntry());
    }

    // Store old variant forms to dispose later
    final oldVariantForms = List<_VariantFormEntry>.from(_variantForms);

    setState(() {
      _variantForms
        ..clear()
        ..addAll(entries);
    });

    // Dispose old controllers after the current frame to avoid
    // "TextEditingController was used after being disposed" errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final variant in oldVariantForms) {
        variant.dispose();
      }
    });
  }

  void _addVariant({
    String? name,
    String? description,
    String? price,
    bool isActive = true,
    String? variantId,
  }) {
    setState(() {
      _variantForms.add(
        _VariantFormEntry(
          name: name,
          description: description,
          price: price,
          isActive: isActive,
          variantId: variantId,
        ),
      );
    });
  }

  void _removeVariant(int index) {
    if (index < 0 || index >= _variantForms.length) return;
    final entry = _variantForms[index];
    setState(() {
      _variantForms.removeAt(index);
      if (_variantForms.isEmpty) {
        _variantForms.add(_VariantFormEntry());
      }
    });
    // Dispose after the current frame to avoid errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      entry.dispose();
    });
  }

  List<Map<String, dynamic>> _buildVariantsPayload() {
    final variants = <Map<String, dynamic>>[];
    for (final entry in _variantForms) {
      final map = entry.toPayload();
      if (map != null) {
        variants.add(map);
      }
    }
    return variants;
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

    final stockText = (state["stock"] ?? "").toString().trim();
    final parsedStock = stockText.isEmpty ? null : int.tryParse(stockText);
    final prepText = (state["preparationTime"] ?? "").toString().trim();
    final parsedPrepTime = prepText.isEmpty ? null : int.tryParse(prepText);
    final additionalText = (state["additionalTime"] ?? "").toString().trim();
    final parsedAdditionalTime =
        additionalText.isEmpty ? null : int.tryParse(additionalText);
    final itemsRaw = (state["itemsIncluded"] ?? "").toString();
    final itemsList = itemsRaw
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final payload = <String, dynamic>{
      "name": state["name"],
      "description": state["description"],
      "size": state["size"],
      "price": state["price"],
      "category_id": state["selectedCategory"],
      "status": state["isActive"] ? "Active" : "Inactive",
      "display_image": state["display_image"],
    };
    final customizable = state["customizable"] == true;

    if (parsedStock != null) {
      payload["stock"] = parsedStock;
    } else if (stockText.isNotEmpty) {
      payload["stock"] = stockText;
    }
    if (parsedPrepTime != null) {
      payload["preparation_time_of_first_unit"] = parsedPrepTime;
    }
    if (parsedAdditionalTime != null) {
      payload["additional_time_to_make_excess_units"] = parsedAdditionalTime;
    }
    if (itemsList.isNotEmpty) {
      payload["items_included"] = itemsList;
    }
    payload["customizable"] = customizable;

    List<Map<String, dynamic>> variantsPayload;
    try {
      variantsPayload = _buildVariantsPayload();
    } on _VariantValidationException catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }

    if (variantsPayload.isNotEmpty) {
      payload["variants_payload"] = variantsPayload;
      payload["customizable"] = true;
    }

    print("dkC: " + jsonEncode(payload));

    final response = await request(
      Uri.parse(url),
      headers: {
        "Authorization": "Token $authToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode(payload),
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

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    const accent = Color(0xFF54A079);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildVariantsEditor(ThemeData theme, {required bool useCard}) {
    final children = <Widget>[];

    if (_variantForms.where((entry) => !entry.isCompletelyEmpty).isEmpty) {
      children.add(
        Text(
          "No variants yet. Add at least one to override the base price.",
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
      );
      children.add(const SizedBox(height: 12));
    }

    for (var index = 0; index < _variantForms.length; index++) {
      children.add(_buildVariantTile(
        theme,
        entry: _variantForms[index],
        index: index,
        useCardDecoration: useCard,
      ));
      if (index != _variantForms.length - 1) {
        children.add(const SizedBox(height: 12));
      }
    }

    children.add(const SizedBox(height: 12));
    children.add(
      OutlinedButton.icon(
        onPressed: () => _addVariant(),
        icon: const Icon(Icons.add),
        label: const Text("Add variant"),
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );

    if (useCard) {
      return _FieldCard(child: content);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: content,
    );
  }

  Widget _buildVariantTile(
    ThemeData theme, {
    required _VariantFormEntry entry,
    required int index,
    required bool useCardDecoration,
  }) {
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    final nameDecoration = useCardDecoration
        ? _fieldDecoration("Variant name", hint: "Eg. Grilled")
        : const InputDecoration(
            labelText: "Variant name",
            border: OutlineInputBorder(),
          );

    final descriptionDecoration = useCardDecoration
        ? _fieldDecoration("Variant description (optional)")
        : const InputDecoration(
            labelText: "Variant description (optional)",
            border: OutlineInputBorder(),
          );

    final priceDecoration = useCardDecoration
        ? _fieldDecoration("Variant price", hint: "₹")
        : const InputDecoration(
            labelText: "Variant price",
            border: OutlineInputBorder(),
          );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: useCardDecoration ? const Color(0xFFFAFBFF) : Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Variant ${index + 1}', style: titleStyle),
              const Spacer(),
              if (_variantForms.length > 1)
                IconButton(
                  tooltip: 'Remove variant',
                  onPressed: () => _removeVariant(index),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: entry.nameController,
            decoration: nameDecoration,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: entry.descriptionController,
            decoration: descriptionDecoration,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: entry.priceController,
            decoration: priceDecoration,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Active',
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              Switch.adaptive(
                value: entry.isActive,
                activeColor: const Color(0xFF54A079),
                onChanged: (value) {
                  setState(() {
                    entry.isActive = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuState = ref.watch(menuItemStateProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(96),
        child: _MenuItemAppBar(
          isEditMode: widget.isEditMode,
          layout: _layout,
          onLayoutChange: (layout) {
            setState(() => _layout = layout);
          },
        ),
      ),
      backgroundColor: const Color(0xFFF6F7FB),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saveProduct,
            icon: Icon(widget.isEditMode ? Icons.save : Icons.add),
            label: Text(
              widget.isEditMode ? "Save changes" : "Create item",
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF54A079),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: _layout == MenuItemLayout.modern
              ? _buildModernForm(
                  context, theme, menuState, categoriesAsync, ref)
              : _buildClassicForm(context, menuState, categoriesAsync, ref),
        ),
      ),
    );
  }

  Widget _buildModernForm(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> menuState,
    AsyncValue<List<Map<String, dynamic>>> categoriesAsync,
    WidgetRef ref,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: "Product image"),
          const SizedBox(height: 12),
          _ProductImageCard(
            imageUrl: resolveMediaUrl(menuState["display_image"] as String?),
            onTap: () => _uploadProductImage(context, ref),
          ),
          const SizedBox(height: 28),
          const _SectionHeader(title: "Basic details"),
          const SizedBox(height: 12),
          _FieldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  decoration: _fieldDecoration(
                    "Item name",
                    hint: "Eg. Masala Chai",
                  ),
                  controller: _nameController,
                  validator: (value) =>
                      value!.isEmpty ? "Please enter item name" : null,
                  onChanged: (value) => ref
                      .read(menuItemStateProvider.notifier)
                      .updateField("name", value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: _fieldDecoration(
                    "Description",
                    hint: "Tell customers what makes this special",
                  ),
                  controller: _descriptionController,
                  maxLines: 3,
                  validator: (value) =>
                      value!.isEmpty ? "Please enter description" : null,
                  onChanged: (value) => ref
                      .read(menuItemStateProvider.notifier)
                      .updateField("description", value),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: _fieldDecoration(
                          "Size / serving",
                          hint: "Eg. 250 ml",
                        ),
                        controller: _sizeController,
                        validator: (value) =>
                            value!.isEmpty ? "Please enter size" : null,
                        onChanged: (value) => ref
                            .read(menuItemStateProvider.notifier)
                            .updateField("size", value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: _fieldDecoration(
                          "Price",
                          hint: "₹",
                        ),
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
                const SizedBox(height: 16),
                TextFormField(
                  decoration: _fieldDecoration(
                    "Items included",
                    hint: "One item per line",
                  ),
                  controller: _itemsIncludedController,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (value) => ref
                      .read(menuItemStateProvider.notifier)
                      .updateField("itemsIncluded", value),
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: menuState["customizable"] == true,
                  title: const Text("Enable variants"),
                  subtitle: const Text(
                    "Allow customers to choose from multiple versions.",
                  ),
                  activeColor: const Color(0xFF54A079),
                  onChanged: (value) => ref
                      .read(menuItemStateProvider.notifier)
                      .updateField("customizable", value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const _SectionHeader(title: "Variants & pricing"),
          const SizedBox(height: 12),
          _buildVariantsEditor(theme, useCard: true),
          const SizedBox(height: 28),
          const _SectionHeader(title: "Timing & preparations"),
          const SizedBox(height: 12),
          _FieldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  decoration: _fieldDecoration(
                    "Preparation Time",
                    hint: "Eg. 5",
                  ),
                  keyboardType: TextInputType.number,
                  controller: _prepTimeController,
                  onChanged: (value) => ref
                      .read(menuItemStateProvider.notifier)
                      .updateField("preparationTime", value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: _fieldDecoration(
                    "Time to make Additional unit",
                    hint: "Eg. 2",
                  ),
                  keyboardType: TextInputType.number,
                  controller: _additionalTimeController,
                  onChanged: (value) => ref
                      .read(menuItemStateProvider.notifier)
                      .updateField("additionalTime", value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const _SectionHeader(title: "Classification"),
          _FieldCard(
            child: categoriesAsync.when(
              data: (categories) {
                if (categories.isEmpty) {
                  return const Text(
                    "No categories available. Create one to continue.",
                  );
                }
                return DropdownButtonFormField<String>(
                  decoration: _fieldDecoration("Category"),
                  value: menuState["selectedCategory"],
                  isExpanded: true,
                  items: categories.map<DropdownMenuItem<String>>(
                    (category) {
                      return DropdownMenuItem<String>(
                        value: category["category_id"],
                        child: Text(category["name"]),
                      );
                    },
                  ).toList(),
                  onChanged: (value) => ref
                      .read(menuItemStateProvider.notifier)
                      .updateField("selectedCategory", value),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (e, _) => const Text(
                "Unable to load categories. Please retry later.",
              ),
            ),
          ),
          const SizedBox(height: 28),
          const _SectionHeader(title: "Availability"),
          const SizedBox(height: 12),
          _FieldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  decoration: _fieldDecoration(
                    "Initial stock",
                    hint: "Eg. 25",
                  ),
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) => ref
                      .read(menuItemStateProvider.notifier)
                      .updateField("stock", value),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Active status",
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            menuState["isActive"]
                                ? "Visible in customer menu."
                                : "Hidden from customer menu.",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: menuState["isActive"],
                      onChanged: (value) => ref
                          .read(menuItemStateProvider.notifier)
                          .updateField("isActive", value),
                      activeColor: const Color(0xFF54A079),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildClassicForm(
    BuildContext context,
    Map<String, dynamic> menuState,
    AsyncValue<List<Map<String, dynamic>>> categoriesAsync,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _uploadProductImage(context, ref),
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: () {
                final url =
                    resolveMediaUrl(menuState["display_image"] as String?);
                if (url == null) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.camera_alt_outlined,
                          size: 36, color: Colors.black45),
                      SizedBox(height: 8),
                      Text(
                        "Tap to upload image",
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  );
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(url, fit: BoxFit.cover),
                );
              }(),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            decoration: const InputDecoration(
              labelText: "Item name",
              border: OutlineInputBorder(),
            ),
            controller: _nameController,
            validator: (value) =>
                value!.isEmpty ? "Please enter item name" : null,
            onChanged: (value) => ref
                .read(menuItemStateProvider.notifier)
                .updateField("name", value),
          ),
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
              labelText: "Description",
              border: OutlineInputBorder(),
            ),
            controller: _descriptionController,
            maxLines: 3,
            validator: (value) =>
                value!.isEmpty ? "Please enter description" : null,
            onChanged: (value) => ref
                .read(menuItemStateProvider.notifier)
                .updateField("description", value),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: "Size / serving",
                    border: OutlineInputBorder(),
                  ),
                  controller: _sizeController,
                  validator: (value) =>
                      value!.isEmpty ? "Please enter size" : null,
                  onChanged: (value) => ref
                      .read(menuItemStateProvider.notifier)
                      .updateField("size", value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Price (₹)",
                    border: OutlineInputBorder(),
                  ),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: "Prep time (mins)",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  controller: _prepTimeController,
                  onChanged: (value) => ref
                      .read(menuItemStateProvider.notifier)
                      .updateField("preparationTime", value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: "Extra time (mins)",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  controller: _additionalTimeController,
                  onChanged: (value) => ref
                      .read(menuItemStateProvider.notifier)
                      .updateField("additionalTime", value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
              labelText: "Items included",
              hintText: "One per line",
              border: OutlineInputBorder(),
            ),
            controller: _itemsIncludedController,
            minLines: 2,
            maxLines: 4,
            onChanged: (value) => ref
                .read(menuItemStateProvider.notifier)
                .updateField("itemsIncluded", value),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            value: menuState["customizable"] == true,
            title: const Text("Enable variants"),
            subtitle: const Text("Allow customers to pick a variant."),
            activeColor: const Color(0xFF54A079),
            onChanged: (value) => ref
                .read(menuItemStateProvider.notifier)
                .updateField("customizable", value),
          ),
          const SizedBox(height: 12),
          _buildVariantsEditor(theme, useCard: false),
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
              labelText: "Initial stock",
              border: OutlineInputBorder(),
            ),
            controller: _stockController,
            keyboardType: TextInputType.number,
            onChanged: (value) => ref
                .read(menuItemStateProvider.notifier)
                .updateField("stock", value),
          ),
          const SizedBox(height: 16),
          categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) {
                return const Text("No categories available");
              }
              return DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Category",
                  border: OutlineInputBorder(),
                ),
                value: menuState["selectedCategory"],
                items: categories.map<DropdownMenuItem<String>>(
                  (category) {
                    return DropdownMenuItem<String>(
                      value: category["category_id"],
                      child: Text(category["name"]),
                    );
                  },
                ).toList(),
                onChanged: (value) => ref
                    .read(menuItemStateProvider.notifier)
                    .updateField("selectedCategory", value),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => const Text("Error loading categories"),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text("Active status"),
            value: menuState["isActive"],
            onChanged: (value) => ref
                .read(menuItemStateProvider.notifier)
                .updateField("isActive", value),
            activeColor: const Color(0xFF54A079),
          ),
          const SizedBox(height: 40),
        ],
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1E3A2F),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

class _ProductImageCard extends StatelessWidget {
  const _ProductImageCard({required this.onTap, this.imageUrl});

  final VoidCallback onTap;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 20,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: imageUrl != null
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                        errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
                      )
                    : const _ImagePlaceholder(),
              ),
              if (imageUrl != null)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0x55000000),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_outlined,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        imageUrl != null ? 'Change image' : 'Upload image',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantValidationException implements Exception {
  const _VariantValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _VariantFormEntry {
  _VariantFormEntry({
    String? name,
    String? description,
    String? price,
    this.isActive = true,
    this.variantId,
  })  : nameController = TextEditingController(text: name ?? ''),
        descriptionController = TextEditingController(text: description ?? ''),
        priceController = TextEditingController(text: price ?? '');

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController priceController;
  bool isActive;
  String? variantId;

  bool get isCompletelyEmpty =>
      nameController.text.trim().isEmpty &&
      descriptionController.text.trim().isEmpty &&
      priceController.text.trim().isEmpty;

  Map<String, dynamic>? toPayload() {
    final name = nameController.text.trim();
    final description = descriptionController.text.trim();
    final price = priceController.text.trim();

    if (name.isEmpty && description.isEmpty && price.isEmpty) {
      return null;
    }

    if (name.isEmpty || price.isEmpty) {
      throw const _VariantValidationException(
        'Every variant needs both a name and a price.',
      );
    }

    final payload = <String, dynamic>{
      'name': name,
      'price': price,
    };

    if (description.isNotEmpty) {
      payload['description'] = description;
    }
    if (!isActive) {
      payload['is_active'] = false;
    }
    if ((variantId ?? '').isNotEmpty) {
      payload['variant_id'] = variantId;
    }
    return payload;
  }

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F1F5),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.photo_size_select_actual_outlined,
              size: 36, color: Color(0xFF9AA2B1)),
          SizedBox(height: 8),
          Text(
            'Tap to add an image',
            style: TextStyle(
              color: Color(0xFF6F7885),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItemAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _MenuItemAppBar({
    required this.isEditMode,
    required this.layout,
    required this.onLayoutChange,
  });

  final bool isEditMode;
  final MenuItemLayout layout;
  final ValueChanged<MenuItemLayout> onLayoutChange;

  @override
  Size get preferredSize => const Size.fromHeight(96);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = isEditMode ? 'Edit product' : 'Add new product';
    final subtitle = isEditMode
        ? 'Update the details customers see in your menu'
        : 'Create a menu item your customers will love';

    return AppBar(
      automaticallyImplyLeading: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      titleSpacing: 16,
      centerTitle: false,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF54A079),
              Color(0xFF3B7C5F),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<MenuItemLayout>(
          tooltip: 'Change layout',
          initialValue: layout,
          onSelected: onLayoutChange,
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: MenuItemLayout.modern,
              child: Text('Modern layout'),
            ),
            PopupMenuItem(
              value: MenuItemLayout.classic,
              child: Text('Classic layout'),
            ),
          ],
          icon: const Icon(Icons.tune),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
