// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';

// import '../../providers/subscription_draft_provider.dart';
// import '../../providers/subscription_slot_provider.dart';
// import '../../models/subscription_models.dart';
// import 'package:geolocator/geolocator.dart';
// import '../../providers/address_provider.dart';
// import '../../providers/outlet_provider.dart';
// import '../../models/outlet_model.dart';
// import 'package:customer_app/services/api_service.dart';

// class CreateSubscriptionReviewScreen extends ConsumerWidget {
//   const CreateSubscriptionReviewScreen({super.key});

//   String _pretty(String ymd) {
//     // ymd is 'yyyy-MM-dd'
//     try {
//       final d = DateTime.parse(ymd);
//       return DateFormat('EEE, d MMM yyyy').format(d);
//     } catch (_) {
//       return ymd;
//     }
//   }

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final draft = ref.watch(subscriptionDraftProvider);
//     final slot = ref.watch(selectedSlotProvider);
//     final primaryAddress = ref.watch(primaryAddressProvider);
//     final selectedOutlet = ref.watch(selectedOutletProvider);
//     if (draft == null) {
//       return Scaffold(
//         appBar: AppBar(title: const Text('Review')),
//         body: const Center(child: Text('No subscription in progress')),
//       );
//     }

//     // Sort by date asc
//     final entries = draft.selections.entries.toList()
//       ..sort((a, b) => a.key.compareTo(b.key));

//     // Compute distance-based serviceability and delivery charge
//     double? distanceKm;
//     if (primaryAddress?.latitude != null &&
//         primaryAddress?.longitude != null &&
//         selectedOutlet?.latitude != null &&
//         selectedOutlet?.longitude != null) {
//       try {
//         final meters = Geolocator.distanceBetween(
//           primaryAddress!.latitude!,
//           primaryAddress.longitude!,
//           selectedOutlet!.latitude,
//           selectedOutlet.longitude,
//         );
//         distanceKm = meters / 1000.0;
//       } catch (_) {}
//     }

//     final bool unserviceable = (distanceKm != null && distanceKm > 5.0);
//     final bool deliveryChargeApplies =
//         (distanceKm != null && distanceKm > 1.0 && distanceKm <= 5.0);
//     final double outletDeliveryCharge = selectedOutlet?.deliveryCharge ?? 0.0;
//     // Apply charge per delivery day when beyond 1km and within 5km
//     final double deliveryCharge = deliveryChargeApplies
//         ? (outletDeliveryCharge * draft.distinctDays)
//         : 0.0;

//     final double payableTotal =
//         (draft.grandTotal + deliveryCharge).clamp(0, double.infinity);

//     return Scaffold(
//       appBar: AppBar(title: const Text('Review Subscription')),
//       body: SafeArea(
//         child: Column(
//           children: [
//             // Header
//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(draft.productName,
//                             style: GoogleFonts.dmSans(
//                               fontSize: 18,
//                               fontWeight: FontWeight.w700,
//                             )),
//                         const SizedBox(height: 4),
//                         Text(
//                           '₹ ${draft.unitPrice.toStringAsFixed(0)} per unit',
//                           style: GoogleFonts.dmSans(
//                             fontSize: 12,
//                             color: Colors.grey[700],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   Flexible(
//                     child: Wrap(
//                       spacing: 8,
//                       runSpacing: 6,
//                       alignment: WrapAlignment.end,
//                       children: [
//                         _chip('${draft.totalUnits} unit(s)'),
//                         _chip('${draft.distinctDays} day(s)'),
//                         if (slot != null) _chip(_slotText(slot)),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),

//             // Address + Outlet + Distance card
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16.0),
//               child: Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFFFFFFF),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: const Color(0xFFE5E7EB)),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Row(
//                     //   children: [
//                     //     const Icon(Icons.store_mall_directory_outlined, size: 18),
//                     //     const SizedBox(width: 8),
//                     //     Expanded(
//                     //       child: Text(
//                     //         selectedOutlet == null
//                     //             ? 'Locating outlet…'
//                     //             : selectedOutlet.address,
//                     //         style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
//                     //         maxLines: 2,
//                     //         overflow: TextOverflow.ellipsis,
//                     //       ),
//                     //     ),
//                     //   ],
//                     // ),
//                     Row(
//                       children: [
//                         const Icon(Icons.location_on_outlined, size: 18),
//                         const SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             primaryAddress == null
//                                 ? 'Select a delivery address'
//                                 : primaryAddress.address,
//                             style: GoogleFonts.dmSans(),
//                             maxLines: 2,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         TextButton(
//                           onPressed: () async {
//                             await Navigator.pushNamed(
//                                 context, '/manage-addresses');
//                           },
//                           child: const Text('Change'),
//                         ),
//                       ],
//                     ),
//                     if (distanceKm != null)
//                       Padding(
//                         padding: const EdgeInsets.only(top: 6.0),
//                         child: Text(
//                           '${distanceKm.toStringAsFixed(2)} km from outlet',
//                           style: GoogleFonts.dmSans(
//                               fontSize: 12, color: Colors.grey[700]),
//                         ),
//                       ),
//                     if (unserviceable)
//                       Padding(
//                         padding: const EdgeInsets.only(top: 6.0),
//                         child: Text(
//                           'Service not available at your location.',
//                           style: GoogleFonts.dmSans(
//                               color: Colors.red[700],
//                               fontWeight: FontWeight.w700),
//                         ),
//                       )
//                     else if (deliveryChargeApplies && outletDeliveryCharge > 0)
//                       Padding(
//                         padding: const EdgeInsets.only(top: 6.0),
//                         child: Text(
//                           'Delivery charge applies: ₹ ${outletDeliveryCharge.toStringAsFixed(0)} per delivery',
//                           style: GoogleFonts.dmSans(
//                               color: Colors.orange[800],
//                               fontWeight: FontWeight.w700),
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(height: 8),

//             const Divider(height: 1),

//             // Scrollable list of selections
//             Expanded(
//               child: entries.isEmpty
//                   ? Center(
//                       child: Padding(
//                         padding: const EdgeInsets.all(24.0),
//                         child: Text(
//                           'No dates selected.\nGo back and pick your dates.',
//                           textAlign: TextAlign.center,
//                           style: GoogleFonts.dmSans(color: Colors.grey[700]),
//                         ),
//                       ),
//                     )
//                   : ListView.separated(
//                       padding: const EdgeInsets.all(16),
//                       itemCount: entries.length,
//                       separatorBuilder: (_, __) => const Divider(height: 12),
//                       itemBuilder: (_, i) {
//                         final e = entries[i];
//                         return ListTile(
//                           dense: true,
//                           leading: const Icon(Icons.event_available),
//                           title: Text(_pretty(e.key)),
//                           trailing: Text('× ${e.value}',
//                               style: GoogleFonts.dmSans(
//                                 fontWeight: FontWeight.w700,
//                               )),
//                         );
//                       },
//                     ),
//             ),

//             // Totals + Proceed pinned at bottom
//             Container(
//               decoration: const BoxDecoration(
//                 color: Colors.white,
//                 border: Border(top: BorderSide(color: Color(0x11000000))),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Color(0x14000000),
//                     blurRadius: 8,
//                     offset: Offset(0, -2),
//                   ),
//                 ],
//               ),
//               child: SafeArea(
//                 top: false,
//                 child: Padding(
//                   padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
//                   child: Row(
//                     children: [
//                       // Totals
//                       Expanded(
//                         child: Wrap(
//                           spacing: 2,
//                           runSpacing: 4,
//                           crossAxisAlignment: WrapCrossAlignment.center,
//                           children: [
//                             _pill(
//                                 'Subtotal ₹ ${draft.itemTotal.toStringAsFixed(0)}'),
//                             if (draft.discount > 0) ...[
//                               _pill(
//                                 'Discount ₹ ${draft.discount.toStringAsFixed(0)}',
//                                 bg: const Color(0xFFE9F7EF),
//                                 fg: const Color(0xFF2E7D32),
//                               ),
//                             ],
//                             if (deliveryCharge > 0) ...[
//                               _pill(
//                                 'Delivery ₹ ${deliveryCharge.toStringAsFixed(0)}',
//                                 bg: const Color(0xFFFFF7E6),
//                                 fg: const Color(0xFF8A6D3B),
//                               ),
//                             ],
//                           ],
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       ElevatedButton(
//                         onPressed: unserviceable
//                             ? null
//                             : () async {
//                                 await _submitSubscriptionOrder(
//                                   context,
//                                   ref,
//                                   draftTotals: (
//                                     subtotal: draft.itemTotal,
//                                     discount: draft.discount,
//                                     delivery: deliveryCharge,
//                                     net: payableTotal,
//                                   ),
//                                 );
//                               },
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: const Color(0xFF54A079),
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 18, vertical: 14),
//                           shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(10)),
//                         ),
//                         child: Text(
//                           unserviceable
//                               ? 'Unavailable'
//                               //: 'Continue',
//                               : 'Pay ₹ ${payableTotal.toStringAsFixed(0)}',
//                           style: GoogleFonts.dmSans(
//                             fontWeight: FontWeight.w700,
//                             color: Colors.white,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   String _slotText(SlotOption s) {
//     String label = s.slotLabel.trim();
//     String? range;
//     try {
//       final st = DateTime.parse(s.slotStart);
//       final en = DateTime.parse(s.slotEnd);
//       final fmt = DateFormat('h:mm a');
//       range = '${fmt.format(st)} – ${fmt.format(en)}';
//     } catch (_) {
//       range = null;
//     }
//     if (label.isNotEmpty && range != null) return '$label';
//     if (label.isNotEmpty) return label;
//     return range ?? 'Time slot';
//   }

//   Widget _chip(String text) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF4F6F8),
//         borderRadius: BorderRadius.circular(999),
//       ),
//       child: Text(
//         text,
//         style: GoogleFonts.dmSans(fontSize: 12),
//         softWrap: false,
//         overflow: TextOverflow.ellipsis,
//         maxLines: 1,
//       ),
//     );
//   }

//   Widget _pill(String text,
//       {Color bg = const Color(0xFFF4F6F8),
//       Color fg = const Color(0xFF2D3748)}) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       decoration: BoxDecoration(
//         color: bg,
//         borderRadius: BorderRadius.circular(999),
//       ),
//       child: Text(
//         text,
//         style: GoogleFonts.dmSans(fontSize: 12, color: fg),
//       ),
//     );
//   }

//   Future<void> _submitSubscriptionOrder(
//     BuildContext context,
//     WidgetRef ref, {
//     required ({
//       double subtotal,
//       double discount,
//       double delivery,
//       double net
//     }) draftTotals,
//   }) async {
//     final draft = ref.read(subscriptionDraftProvider);
//     final slot = ref.read(selectedSlotProvider);
//     final primaryAddress = ref.read(primaryAddressProvider);
//     final selectedOutlet = ref.read(selectedOutletProvider);

//     if (draft == null ||
//         slot == null ||
//         primaryAddress == null ||
//         selectedOutlet == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//             content: Text('Missing details to place subscription order.')),
//       );
//       return;
//     }

//     // Build subscription_detail from selected dates
//     final entries = draft.selections.entries.toList()
//       ..sort((a, b) => a.key.compareTo(b.key));
//     final List<Map<String, dynamic>> details = [
//       for (final e in entries) {"date": e.key, "qty": e.value}
//     ];

//     // Build time slot string
//     String timeSlot = slot.slotLabel.trim();
//     if (timeSlot.isEmpty) {
//       try {
//         final st = DateTime.parse(slot.slotStart);
//         final en = DateTime.parse(slot.slotEnd);
//         final tf = DateFormat('HH:mm');
//         timeSlot = '${tf.format(st)} - ${tf.format(en)}';
//       } catch (_) {}
//     }

//     // Parse numeric fields with safe fallbacks
//     final outletId = selectedOutlet.outletId.toString();
//     final addressId = primaryAddress.addressId.toString();
//     if (outletId == "" || addressId == "") {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Invalid outlet or address id.')),
//       );
//       return;
//     }

//     // 1) Create the subscription first
//     final apiCreate = ApiService();
//     final List<Map<String, dynamic>> createDays = [
//       for (final e in entries)
//         {
//           "date": e.key,
//           "qty": e.value,
//           if (slot.slotStart.isNotEmpty) "slot_start": slot.slotStart,
//         }
//     ];
//     try {
//       final createBody = {
//         "product_id": draft.productId,
//         "outlet_id": selectedOutlet.outletId,
//         "days": createDays,
//         "address_id": primaryAddress.addressId,
//         "payment_method": "prepaid",
//       };
//       final resp =
//           await apiCreate.post('/api/subscriptions/create/', createBody);

//       if (resp.statusCode >= 200 && resp.statusCode < 300) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Subscription created successfully.')),
//         );
//         // Clear the draft
//         ref.read(subscriptionDraftProvider.notifier).clear();
//         // Navigate to subscriptions screen
//         Navigator.pushNamedAndRemoveUntil(
//             context, '/menu', (route) => route.isFirst);
//       } else {
//         String errorMsg = 'Create failed: ${resp.statusCode}';
//         try {
//           final errData = jsonDecode(resp.body);
//           if (errData is Map && errData['error'] is String) {
//             errorMsg = 'Create failed: ${errData['error']}';
//           }
//         } catch (_) {}
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(errorMsg)),
//         );
//       }

//       // dynamic created;
//       // try {
//       //   created = jsonDecode(createResp.body);
//       // } catch (_) {
//       //   created = null;
//       // }
//       // // Try to extract subscription_id from the response
//       // dynamic sid = (created is Map)
//       //     ? (created['subscription_id'] ??
//       //         created['id'] ??
//       //         (created['subscription'] is Map
//       //             ? created['subscription']['id']
//       //             : null))
//       //     : null;
//       // final subscriptionId = sid is int ? sid : int.tryParse('${sid ?? ''}');

//       // // If we can't get an id, show success for creation and exit
//       // if (subscriptionId == null) {
//       //   ScaffoldMessenger.of(context).showSnackBar(
//       //     const SnackBar(
//       //         content: Text('Subscription created, but id missing.')),
//       //   );
//       //   return;
//       // }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Create failed: $e')),
//       );
//     }
//   }

//   // Section wrapper styling similar to Cart screen
//   Widget _sectionBox(Widget child) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.3),
//             spreadRadius: 1,
//             blurRadius: 5,
//             offset: const Offset(0, 2),
//           )
//         ],
//       ),
//       child: child,
//     );
//   }

//   Widget _kvRow(String label, String value,
//       {bool isBold = false, Color? valueColor}) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(
//           label,
//           style: GoogleFonts.dmSans(
//             fontSize: 14,
//             fontWeight: FontWeight.bold,
//             color: Colors.black,
//           ),
//         ),
//         Text(
//           value,
//           style: GoogleFonts.dmSans(
//             fontSize: 12,
//             fontWeight: isBold ? FontWeight.w800 : FontWeight.bold,
//             color: valueColor ?? Colors.grey[600],
//           ),
//         ),
//       ],
//     );
//   }
// }
