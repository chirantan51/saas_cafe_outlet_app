// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:outlet_app/data/models/order_model.dart';
// import 'package:outlet_app/providers/auth_provider.dart';
// import 'package:outlet_app/providers/menu_provider.dart';
// import 'package:outlet_app/providers/recent_orders_provider.dart';
// import 'package:outlet_app/services/order_service.dart';

// class EditDineInOrderScreen extends ConsumerStatefulWidget {
//   const EditDineInOrderScreen({super.key, required this.order});

//   final OrderModel order;

//   @override
//   ConsumerState<EditDineInOrderScreen> createState() => _EditDineInOrderScreenState();
// }

// class _EditDineInOrderScreenState extends ConsumerState<EditDineInOrderScreen> {
//   final List<_EditableOrderItem> _items = [];
//   bool _saving = false;

//   @override
//   void initState() {
//     super.initState();
//     for (final item in widget.order.items) {
//       final basePrice = item.unitPrice ?? item.price;
//       _items.add(
//         _EditableOrderItem(
//           orderItemId: item.orderItemId,
//           productId: item.productId,
//           productName: item.productName,
//           unitPrice: basePrice,
//           quantity: item.quantity,
//           variantId: item.variantId,
//           variantName: item.variantName,
//           customizations: List<Map<String, dynamic>>.from(item.customizations),
//         ),
//       );
//     }
//   }

//   double get _grossTotal => _items.fold<double>(0, (sum, item) => sum + item.lineTotal);

//   double get _discountAmount => widget.order.discountAmount;

//   double get _deliveryCharges => widget.order.deliveryCharges;

//   double get _netTotal => _grossTotal - _discountAmount + _deliveryCharges;

//   bool get _canSave => _items.isNotEmpty && !_saving;

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final menuState = ref.watch(menuProvider);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Edit Dine-in Order'),
//       ),
//       floatingActionButton: FloatingActionButton.extended(
//         onPressed: menuState.isLoading ? null : _handleAddItem,
//         icon: const Icon(Icons.add),
//         label: const Text('Add product'),
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: _items.isEmpty
//                 ? const Center(child: Text('No items in this order.'))
//                 : ListView.builder(
//                     padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
//                     itemCount: _items.length,
//                     itemBuilder: (context, index) {
//                       final item = _items[index];
//                       return Card(
//                         margin: const EdgeInsets.symmetric(vertical: 8),
//                         child: Padding(
//                           padding: const EdgeInsets.all(16),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Row(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Expanded(
//                                     child: Column(
//                                       crossAxisAlignment: CrossAxisAlignment.start,
//                                       children: [
//                                         Text(
//                                           item.productName,
//                                           style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
//                                         ),
//                                         if ((item.variantName ?? '').isNotEmpty)
//                                           Padding(
//                                             padding: const EdgeInsets.only(top: 4),
//                                             child: Text(
//                                               item.variantName!,
//                                               style: theme.textTheme.bodySmall?.copyWith(
//                                                 fontWeight: FontWeight.w600,
//                                                 color: theme.colorScheme.primary,
//                                               ),
//                                             ),
//                                           ),
//                                       ],
//                                     ),
//                                   ),
//                                   Text('₹${item.unitPrice.toStringAsFixed(2)}'),
//                                 ],
//                               ),
//                               const SizedBox(height: 12),
//                               Row(
//                                 children: [
//                                   IconButton(
//                                     onPressed: () => _decrementQuantity(index),
//                                     icon: const Icon(Icons.remove_circle_outline),
//                                   ),
//                                   Text('${item.quantity}', style: theme.textTheme.titleMedium),
//                                   IconButton(
//                                     onPressed: () => _incrementQuantity(index),
//                                     icon: const Icon(Icons.add_circle_outline),
//                                   ),
//                                   const Spacer(),
//                                   Text(
//                                     '₹${item.lineTotal.toStringAsFixed(2)}',
//                                     style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
//                                   ),
//                                 ],
//                               ),
//                               if (item.customizations.isNotEmpty)
//                                 Padding(
//                                   padding: const EdgeInsets.only(top: 8),
//                                   child: Text(
//                                     'Customizations: ${item.customizations.map((e) => e['instruction']).whereType<String>().where((text) => text.trim().isNotEmpty).join(', ')}',
//                                     style: theme.textTheme.bodySmall,
//                                   ),
//                                 ),
//                               Align(
//                                 alignment: Alignment.centerRight,
//                                 child: TextButton.icon(
//                                   onPressed: () => _removeItem(index),
//                                   icon: const Icon(Icons.delete_outline),
//                                   label: const Text('Remove'),
//                                   style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//           ),
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
//             decoration: BoxDecoration(
//               color: theme.colorScheme.surface,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.05),
//                   blurRadius: 8,
//                   offset: const Offset(0, -2),
//                 ),
//               ],
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const Text('Gross total'),
//                     Text('₹${_grossTotal.toStringAsFixed(2)}'),
//                   ],
//                 ),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const Text('Discount'),
//                     Text('₹${_discountAmount.toStringAsFixed(2)}'),
//                   ],
//                 ),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const Text('Delivery charges'),
//                     Text('₹${_deliveryCharges.toStringAsFixed(2)}'),
//                   ],
//                 ),
//                 const Divider(height: 20),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       'Net total',
//                       style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
//                     ),
//                     Text(
//                       '₹${_netTotal.toStringAsFixed(2)}',
//                       style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 16),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: OutlinedButton(
//                         onPressed: _saving ? null : () => Navigator.of(context).pop(false),
//                         child: const Text('Discard changes'),
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: FilledButton(
//                         onPressed: _canSave ? _saveChanges : null,
//                         child: _saving
//                             ? const SizedBox(
//                                 width: 18,
//                                 height: 18,
//                                 child: CircularProgressIndicator(strokeWidth: 2),
//                               )
//                             : const Text('Save changes'),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _incrementQuantity(int index) {
//     setState(() => _items[index].quantity += 1);
//   }

//   void _decrementQuantity(int index) {
//     final item = _items[index];
//     if (item.quantity > 1) {
//       setState(() => item.quantity -= 1);
//     }
//   }

//   void _removeItem(int index) {
//     setState(() => _items.removeAt(index));
//   }

//   Future<void> _handleAddItem() async {
//     final newItem = await _showAddItemDialog();
//     if (newItem == null) return;

//     setState(() {
//       final existingIndex = _items.indexWhere((item) =>
//           item.productId == newItem.productId && item.variantId == newItem.variantId);
//       if (existingIndex != -1) {
//         _items[existingIndex].quantity += newItem.quantity;
//       } else {
//         _items.add(newItem);
//       }
//     });
//   }

//   Future<_EditableOrderItem?> _showAddItemDialog() async {
//     final menuState = ref.read(menuProvider);
//     if (menuState.isLoading) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Menu is still loading. Please wait.')),
//       );
//       return null;
//     }
//     final menuItems = menuState.items;
//     if (menuItems.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No menu items available.')),
//       );
//       return null;
//     }

//     String query = '';

//     return showDialog<_EditableOrderItem>(
//       context: context,
//       builder: (dialogContext) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             final filtered = query.isEmpty
//                 ? menuItems
//                 : menuItems.where((item) {
//                     final name = item['name']?.toString().toLowerCase() ?? '';
//                     final description =
//                         item['description']?.toString().toLowerCase() ?? '';
//                     return name.contains(query.toLowerCase()) ||
//                         description.contains(query.toLowerCase());
//                   }).toList();

//             return AlertDialog(
//               title: const Text('Add product'),
//               content: SizedBox(
//                 width: double.maxFinite,
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     TextField(
//                       decoration: const InputDecoration(
//                         prefixIcon: Icon(Icons.search),
//                         hintText: 'Search products',
//                       ),
//                       onChanged: (value) {
//                         setState(() => query = value.trim());
//                       },
//                     ),
//                     const SizedBox(height: 12),
//                     Expanded(
//                       child: filtered.isEmpty
//                           ? const Center(child: Text('No products found.'))
//                           : ListView.builder(
//                               itemCount: filtered.length,
//                               itemBuilder: (context, index) {
//                                 final product = filtered[index];
//                                 return ListTile(
//                                   title: Text(product['name']?.toString() ?? 'Product'),
//                                   subtitle: Text(
//                                     '₹${_parsePrice(product['price']).toStringAsFixed(2)}',
//                                   ),
//                                   onTap: () async {
//                                     final variants = (product['variants'] as List?)
//                                             ?.whereType<Map<String, dynamic>>()
//                                             .toList() ??
//                                         const [];
//                                     Map<String, dynamic>? chosenVariant;
//                                     if (variants.isNotEmpty) {
//                                       chosenVariant = await _pickVariant(product['name'], variants);
//                                       if (chosenVariant == null) return;
//                                     }
//                                     Navigator.of(dialogContext).pop(_EditableOrderItem(
//                                       orderItemId: null,
//                                       productId: product['id']?.toString() ??
//                                           product['product_id']?.toString() ??
//                                           '',
//                                       productName: product['name']?.toString() ?? 'Product',
//                                       unitPrice: _parsePrice(
//                                           chosenVariant != null ? chosenVariant['price'] : product['price']),
//                                       quantity: 1,
//                                       variantId: chosenVariant?['variant_id']?.toString() ??
//                                           chosenVariant?['id']?.toString(),
//                                       variantName: chosenVariant?['name']?.toString(),
//                                       customizations: const <Map<String, dynamic>>[],
//                                     ));
//                                   },
//                                 );
//                               },
//                             ),
//                     ),
//                   ],
//                 ),
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.of(dialogContext).pop(),
//                   child: const Text('Close'),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   Future<Map<String, dynamic>?> _pickVariant(
//     String productName,
//     List<Map<String, dynamic>> variants,
//   ) async {
//     return showDialog<Map<String, dynamic>>(
//       context: context,
//       builder: (variantContext) {
//         return SimpleDialog(
//           title: Text('Select variant for $productName'),
//           children: variants
//               .map(
//                 (variant) => SimpleDialogOption(
//                   onPressed: () => Navigator.of(variantContext).pop(variant),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(variant['name']?.toString() ?? 'Variant'),
//                       Text(
//                         '₹${_parsePrice(variant['price']).toStringAsFixed(2)}',
//                         style: Theme.of(context).textTheme.bodySmall,
//                       ),
//                     ],
//                   ),
//                 ),
//               )
//               .toList(),
//         );
//       },
//     );
//   }

//   double _parsePrice(dynamic value) {
//     if (value == null) return 0.0;
//     if (value is num) return value.toDouble();
//     return double.tryParse(value.toString()) ?? 0.0;
//   }

//   Future<void> _saveChanges() async {
//     if (!_canSave) return;
//     final authToken = ref.read(authProvider).authToken;
//     if (authToken == null || authToken.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Missing authentication token.')),
//       );
//       return;
//     }

//     setState(() => _saving = true);

//     final payloadItems = _items.map((item) => item.toJson()).toList();
//     final success = await updateDineInOrder(
//       orderId: widget.order.orderId,
//       outletId: widget.order.outletId ?? '',
//       status: widget.order.status,
//       deliveryType: widget.order.deliveryType ?? 'dine_in',
//       grossTotal: _grossTotal,
//       discountAmount: _discountAmount,
//       deliveryCharges: _deliveryCharges,
//       netTotal: _netTotal,
//       items: payloadItems,
//       authToken: authToken,
//     );

//     if (!mounted) return;

//     setState(() => _saving = false);

//     if (!success) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Failed to update order.')),
//       );
//       return;
//     }

//     ref.invalidate(recentOrdersProvider);
//     Navigator.of(context).pop(true);
//   }
// }

// class _EditableOrderItem {
//   _EditableOrderItem({
//     this.orderItemId,
//     required this.productId,
//     required this.productName,
//     required this.unitPrice,
//     required this.quantity,
//     this.variantId,
//     this.variantName,
//     List<Map<String, dynamic>>? customizations,
//   }) : customizations = customizations ?? <Map<String, dynamic>>[];

//   final int? orderItemId;
//   final String productId;
//   final String productName;
//   final String? variantId;
//   final String? variantName;
//   final double unitPrice;
//   int quantity;
//   final List<Map<String, dynamic>> customizations;

//   double get lineTotal => unitPrice * quantity;

//   Map<String, dynamic> toJson() {
//     return {
//       if (orderItemId != null) 'order_item_id': orderItemId,
//       'product': productId,
//       'product_name': productName,
//       'quantity': quantity,
//       'price': unitPrice.toStringAsFixed(2),
//       if (variantId != null) 'variant': variantId,
//       'customizations': customizations,
//     };
//   }
// }
