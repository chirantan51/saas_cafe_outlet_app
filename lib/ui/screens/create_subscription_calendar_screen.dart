// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
// import 'package:customer_app/services/api_service.dart';

// import '../../models/subscription_draft.dart';
// import '../../providers/subscription_draft_provider.dart';
// import '../../models/subscription_models.dart';
// import '../../providers/subscription_slot_provider.dart';

// /// Simple add-on catalog item (local to this screen for now).
// class AddonItem {
//   final String id;
//   final String name;
//   final double price;
//   const AddonItem({required this.id, required this.name, required this.price});
// }

// class CreateSubscriptionCalendarScreen extends ConsumerStatefulWidget {
//   /// If false, all Sundays are disabled.
//   final bool sundaySelectable;

//   /// Dates that are not available for selection.
//   final Set<DateTime> holidays;

//   /// Menu plan per date (yyyy-MM-dd -> bullet points).
//   final Map<String, List<String>> menuPlan;

//   /// Optional catalog of add-ons to show in the bottom sheet.
//   final List<AddonItem> addonsCatalog;

//   /// Delivery time used to compute add-ons cutoff lock (default 13:00).
//   final TimeOfDay deliveryTime;

//   /// How many hours before delivery add-ons get locked (default 4h).
//   final int addonsCutoffHours;

//   /// Available time slots (from product.sub_config.available_slots).
//   final List<SlotOption> slots;

//   /// When true, the screen behaves as an edit flow for an existing subscription.
//   final bool isEditing;

//   /// If provided in edit mode, lock total units to this value.
//   final int? lockedUnits;

//   /// Original selections snapshot for diffing during edit.
//   final Map<String, int> originalSelections;

//   /// Subscription identifier for edit API calls.
//   final int? subscriptionId;

//   const CreateSubscriptionCalendarScreen({
//     super.key,
//     this.sundaySelectable = true,
//     this.holidays = const <DateTime>{},
//     this.menuPlan = const <String, List<String>>{},
//     this.addonsCatalog = const <AddonItem>[
//       AddonItem(id: 'roti', name: 'Extra Roti (2)', price: 12),
//       AddonItem(id: 'papad', name: 'Papad', price: 10),
//       AddonItem(id: 'chhash', name: 'Chhash', price: 20),
//       AddonItem(id: 'sweet', name: 'Sweet', price: 25),
//     ],
//     this.deliveryTime = const TimeOfDay(hour: 13, minute: 0),
//     this.addonsCutoffHours = 4,
//     this.slots = const <SlotOption>[],
//     this.isEditing = false,
//     this.lockedUnits,
//     this.originalSelections = const <String, int>{},
//     this.subscriptionId,
//   });

//   @override
//   ConsumerState<CreateSubscriptionCalendarScreen> createState() =>
//       _CreateSubscriptionCalendarScreenState();
// }

// class _CreateSubscriptionCalendarScreenState
//     extends ConsumerState<CreateSubscriptionCalendarScreen> {
//   late final DateTime _today;
//   late DateTime _rangeStart;
//   late DateTime _rangeEnd;
//   late List<DateTime> _monthAnchors; // first-of-month list inside range

//   final PageController _pageController = PageController();
//   int _pageIndex = 0;

//   DateTime? _focusedDate; // controls the shared qty widget

//   /// Local add-ons state: dateKey -> {addonId: qty}
//   final Map<String, Map<String, int>> _addonsByDate = {};

//   /// Loaded from API: yyyy-MM-dd -> list of menu strings
//   Map<String, List<String>> _menuPlan = const {};
//   bool _menuLoading = false;
//   String? _menuError;

//   @override
//   void initState() {
//     super.initState();
//     _today = _dateOnly(DateTime.now());
//     // Reset any previously selected slot after first frame to avoid
//     // modifying providers during widget lifecycle methods.
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       ref.read(selectedSlotProvider.notifier).state = null;
//     });

//     final s = ref.read(subscriptionDraftProvider);
//     final horizon = (s?.horizonDays ?? 45).clamp(1, 365);
//     _rangeStart = _today;
//     _rangeEnd = _dateOnly(_today.add(Duration(days: horizon - 1)));

//     _monthAnchors = _buildMonthAnchors(_rangeStart, _rangeEnd);

//     // Seed with any provided menuPlan, then fetch live data for the product
//     _menuPlan = Map<String, List<String>>.from(widget.menuPlan);
//     _fetchMenuPlan();
//   }

//   // ── Helpers ─────────────────────────────────────────────────
//   static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
//   static String _key(DateTime d) =>
//       DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));

//   List<DateTime> _buildMonthAnchors(DateTime start, DateTime end) {
//     final first = DateTime(start.year, start.month, 1);
//     final last = DateTime(end.year, end.month, 1);
//     final out = <DateTime>[];
//     var m = first;
//     while (!DateTime(m.year, m.month).isAfter(last)) {
//       out.add(m);
//       m = DateTime(m.year, m.month + 1, 1);
//     }
//     return out;
//   }

//   bool _inRange(DateTime d) =>
//       !d.isBefore(_rangeStart) && !d.isAfter(_rangeEnd);

//   bool _isHoliday(DateTime d) {
//     final k = _key(d);
//     for (final h in widget.holidays) {
//       if (_key(h) == k) return true;
//     }
//     return false;
//   }

//   bool _isLockedForAddons(DateTime date) {
//     // Add-ons lock at (date + deliveryTime) - cutoffHours
//     final cut = DateTime(
//       date.year,
//       date.month,
//       date.day,
//       widget.deliveryTime.hour,
//       widget.deliveryTime.minute,
//     ).subtract(Duration(hours: widget.addonsCutoffHours));
//     return DateTime.now().isAfter(cut);
//   }

//   // ── Remote menu fetch ───────────────────────────────────────
//   Future<void> _fetchMenuPlan() async {
//     final draft = ref.read(subscriptionDraftProvider);
//     if (draft == null) return; // nothing to fetch without a selected product
//     final productId = draft.productId;
//     setState(() {
//       _menuLoading = true;
//       _menuError = null;
//     });

//     try {
//       final api = ApiService();
//       final resp = await api.get('/api/subscriptions/products/$productId/menu/?outlet_id=1');
//       if (resp.statusCode < 200 || resp.statusCode >= 300) {
//         throw Exception('HTTP ${resp.statusCode}');
//       }
//       final dynamic data = jsonDecode(resp.body);
//       final norm = _normalizeMenu(data);
//       setState(() {
//         _menuPlan = norm;
//         _menuLoading = false;
//         _menuError = null;
//       });
//     } catch (e) {
//       setState(() {
//         _menuLoading = false;
//         _menuError = e.toString();
//       });
//     }
//   }

//   Map<String, List<String>> _normalizeMenu(dynamic data) {
//     // Accept a few shapes and return a normalized map
//     final out = <String, List<String>>{};

//     if (data is Map) {
//       // Case A: {"menu": [{"date":"YYYY-MM-DD", "items":[..]}]}
//       if (data['menu'] is List) {
//         for (final it in (data['menu'] as List)) {
//           if (it is Map) {
//             final k = (it['date'] ?? '').toString();
//             final items = (it['items'] as List?) ?? const [];
//             final lines = items
//                 .map((e) => e?.toString() ?? '')
//                 .where((s) => s.trim().isNotEmpty)
//                 .cast<String>()
//                 .toList();
//             if (k.isNotEmpty) out[k] = lines;
//           }
//         }
//         return out;
//       }

//       // Case B: {"YYYY-MM-DD": ["..",".."], ...}
//       bool looksLikeDirect = true;
//       for (final entry in data.entries) {
//         final key = entry.key?.toString() ?? '';
//         if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) { looksLikeDirect = false; break; }
//       }
//       if (looksLikeDirect) {
//         for (final e in data.entries) {
//           final key = e.key.toString();
//           final items = (e.value as List?) ?? const [];
//           final lines = items
//               .map((x) => x?.toString() ?? '')
//               .where((s) => s.trim().isNotEmpty)
//               .cast<String>()
//               .toList();
//           out[key] = lines;
//         }
//         return out;
//       }
//     }

//     if (data is List) {
//       // Case C: [ {date, items}, ... ]
//       for (final it in data) {
//         if (it is Map) {
//           final k = (it['date'] ?? '').toString();
//           final items = (it['items'] as List?) ?? const [];
//           final lines = items
//               .map((e) => e?.toString() ?? '')
//               .where((s) => s.trim().isNotEmpty)
//               .cast<String>()
//               .toList();
//           if (k.isNotEmpty) out[k] = lines;
//         }
//       }
//       return out;
//     }

//     // Fallback: return whatever we already had
//     return _menuPlan;
//   }

//   void _goPrev() {
//     if (_pageIndex > 0) {
//       _pageController.previousPage(
//         duration: const Duration(milliseconds: 220),
//         curve: Curves.easeOut,
//       );
//     }
//   }

//   void _goNext() {
//     if (_pageIndex < _monthAnchors.length - 1) {
//       _pageController.nextPage(
//         duration: const Duration(milliseconds: 220),
//         curve: Curves.easeOut,
//       );
//     }
//   }

//   // ── Add-ons helpers ─────────────────────────────────────────
//   int _addonsCountFor(String k) {
//     final m = _addonsByDate[k];
//     if (m == null || m.isEmpty) return 0;
//     return m.values.fold(0, (a, b) => a + b);
//   }

//   double _addonsTotalFor(String k) {
//     final m = _addonsByDate[k];
//     if (m == null || m.isEmpty) return 0;
//     double sum = 0;
//     for (final entry in m.entries) {
//       final meta = widget.addonsCatalog.firstWhere(
//         (a) => a.id == entry.key,
//         orElse: () => const AddonItem(id: '_', name: '_', price: 0),
//       );
//       sum += meta.price * entry.value;
//     }
//     return sum;
//   }

//   Future<void> _openAddonsSheet(BuildContext context, DateTime date) async {
//     final dk = _key(date);
//     final locked = _isLockedForAddons(date);
//     if (locked) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Add-ons are locked for this date.')),
//       );
//       return;
//     }

//     // Initialize working copy
//     final working = Map<String, int>.from(_addonsByDate[dk] ?? {});

//     await showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       useSafeArea: true,
//       backgroundColor: Colors.white,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (ctx) {
//         return StatefulBuilder(builder: (ctx, setSheet) {
//           double subtotal = 0;
//           int count = 0;
//           for (final e in working.entries) {
//             final meta = widget.addonsCatalog.firstWhere(
//               (a) => a.id == e.key,
//               orElse: () => const AddonItem(id: '_', name: '_', price: 0),
//             );
//             subtotal += meta.price * e.value;
//             count += e.value;
//           }

//           return Padding(
//             padding: EdgeInsets.only(
//               bottom: MediaQuery.of(ctx).viewInsets.bottom,
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Container(
//                   margin: const EdgeInsets.only(top: 8),
//                   width: 40,
//                   height: 4,
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade300,
//                     borderRadius: BorderRadius.circular(99),
//                   ),
//                 ),
//                 Padding(
//                   padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           'Add-ons • ${DateFormat('EEE, d MMM').format(date)}',
//                           style: GoogleFonts.dmSans(
//                             fontWeight: FontWeight.w800,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                       Text(
//                         count > 0 ? '₹ ${subtotal.toStringAsFixed(0)}' : '',
//                         style: GoogleFonts.dmSans(
//                           fontWeight: FontWeight.w800,
//                           fontSize: 14,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const Divider(height: 1),

//                 // List of add-ons
//                 Flexible(
//                   child: ListView.separated(
//                     shrinkWrap: true,
//                     padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
//                     itemCount: widget.addonsCatalog.length,
//                     separatorBuilder: (_, __) => const Divider(height: 16),
//                     itemBuilder: (_, i) {
//                       final item = widget.addonsCatalog[i];
//                       final q = working[item.id] ?? 0;

//                       return Row(
//                         children: [
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(item.name,
//                                     style: GoogleFonts.dmSans(
//                                       fontWeight: FontWeight.w700,
//                                     )),
//                                 const SizedBox(height: 2),
//                                 Text('₹ ${item.price.toStringAsFixed(0)}',
//                                     style: GoogleFonts.dmSans(
//                                       color: Colors.grey[700],
//                                     )),
//                               ],
//                             ),
//                           ),
//                           _QtyMini(
//                             qty: q,
//                             onChanged: (next) {
//                               setSheet(() {
//                                 if (next <= 0) {
//                                   working.remove(item.id);
//                                 } else {
//                                   working[item.id] = next;
//                                 }
//                               });
//                             },
//                           ),
//                         ],
//                       );
//                     },
//                   ),
//                 ),

//                 // Save bar
//                 Container(
//                   width: double.infinity,
//                   padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     border: Border(
//                       top: BorderSide(color: Colors.grey.shade200),
//                     ),
//                   ),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           count > 0
//                               ? 'Add-ons: $count • ₹ ${subtotal.toStringAsFixed(0)}'
//                               : 'No add-ons selected',
//                           style: GoogleFonts.dmSans(
//                             fontWeight: FontWeight.w700,
//                           ),
//                         ),
//                       ),
//                       ElevatedButton(
//                         onPressed: () {
//                           setState(() {
//                             if (working.isEmpty) {
//                               _addonsByDate.remove(dk);
//                             } else {
//                               _addonsByDate[dk] = Map.from(working);
//                             }
//                           });
//                           Navigator.pop(ctx);
//                         },
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: const Color(0xFF54A079),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 16,
//                             vertical: 12,
//                           ),
//                         ),
//                         child: const Text('Save'),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           );
//         });
//       },
//     );
//   }

//   // ── Build ───────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     final draft = ref.watch(subscriptionDraftProvider);

//     if (draft == null) {
//       return Scaffold(
//         appBar: AppBar(title: const Text('Select Dates')),
//         body: const Center(child: Text('No product selected')),
//       );
//     }

//     final lockedUnits = widget.lockedUnits;
//     final unitsValid = !widget.isEditing || lockedUnits == null || draft.totalUnits == lockedUnits;
//     final canContinue = widget.isEditing
//         ? draft.distinctDays > 0
//         : draft.distinctDays >= draft.minDays;
//     final actionEnabled = widget.isEditing
//         ? (draft.distinctDays > 0 && unitsValid)
//         : canContinue;
//     final appTitle =
//         '${draft.productName} • ₹${draft.unitPrice.toStringAsFixed(0)}';

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           widget.isEditing ? 'Edit Schedule' : 'Select Dates',
//           style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
//         ),
//         actions: [
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
//             child: Chip(
//               label: Text(
//                 '${draft.distinctDays}d • ${draft.totalUnits}u',
//                 style: const TextStyle(color: Colors.white),
//               ),
//               backgroundColor: const Color(0xFF54A079),
//             ),
//           ),
//         ],
//       ),
//       body: SafeArea(
//         child: Column(
//           children: [
//             // Header: product + month nav
//             ListTile(
//               dense: true,
//               contentPadding: const EdgeInsets.symmetric(horizontal: 16),
//               title: Text(appTitle,
//                   style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
//               subtitle: Text(
//                 widget.isEditing
//                     ? 'Update your upcoming delivery dates'
//                     : 'Select at least ${draft.minDays} day(s)',
//               ),
//               leading: const Icon(Icons.fastfood),
//               trailing: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   IconButton(
//                     tooltip: 'Previous month',
//                     icon: const Icon(Icons.chevron_left),
//                     onPressed: _pageIndex == 0 ? null : _goPrev,
//                   ),
//                   IconButton(
//                     tooltip: 'Next month',
//                     icon: const Icon(Icons.chevron_right),
//                     onPressed:
//                         _pageIndex == _monthAnchors.length - 1 ? null : _goNext,
//                   ),
//                 ],
//               ),
//             ),
//             const Divider(height: 1),

//             // Calendar
//             Expanded(
//               child: PageView.builder(
//                 controller: _pageController,
//                 itemCount: _monthAnchors.length,
//                 onPageChanged: (i) => setState(() => _pageIndex = i),
//                 itemBuilder: (_, i) {
//                   final monthAnchor = _monthAnchors[i];
//                   return _MonthGrid(
//                     monthAnchor: monthAnchor,
//                     inRange: _inRange,
//                     isHoliday: _isHoliday,
//                     sundaySelectable: widget.sundaySelectable,
//                     today: _today,
//                     selections: draft.selections,
//                     onDayTap: (date) {
//                       if (_isHoliday(date)) {
//                         // Allow focusing to show "Holiday" in footer, but do not select.
//                         setState(() => _focusedDate = date);
//                         return;
//                       }
//                       final ntf = ref.read(subscriptionDraftProvider.notifier);
//                       if (!ntf.isSelected(date)) {
//                         ntf.ensureSelected(date);
//                       }
//                       setState(() => _focusedDate = date);
//                     },
//                     onDayLongPress: (date) {
//                       if (_isHoliday(date)) {
//                         setState(() => _focusedDate = date);
//                         return;
//                       }
//                       setState(() => _focusedDate = date);
//                     },
//                   );
//                 },
//               ),
//             ),

//             // Footer: Qty + Menu + Add-ons + Totals + Continue
//             _Footer(
//               focusedDate: _focusedDate,
//               draft: draft,
//               menuPlan: _menuPlan,
//               isHolidayFocused: _focusedDate == null ? false : _isHoliday(_focusedDate!),
//               maxPerDay: draft.maxPerDay,
//               addonsByDate: _addonsByDate,
//               addonsCatalog: widget.addonsCatalog,
//               addonsLocked: _focusedDate == null
//                   ? false
//                   : _isLockedForAddons(_focusedDate!),
//               onOpenAddons: _focusedDate == null
//                   ? null
//                   : () => _openAddonsSheet(context, _focusedDate!),
//               onQtyChanged: (qty) {
//                 final d = _focusedDate;
//                 if (d == null) return;
//                 ref.read(subscriptionDraftProvider.notifier).setQty(d, qty);
//                 if (qty <= 0) setState(() => _focusedDate = null);
//               },
//               buttonLabel: widget.isEditing ? 'Update' : 'Continue',
//               isEditing: widget.isEditing,
//               lockedUnits: lockedUnits,
//               unitsValid: unitsValid,
//               onContinue: actionEnabled ? () => _handleContinue(context) : null,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _handleContinue(BuildContext context) async {
//     final draft = ref.read(subscriptionDraftProvider);
//     if (draft == null) return;

//     if (widget.isEditing) {
//       if (widget.lockedUnits != null && draft.totalUnits != widget.lockedUnits) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               'Total units must remain ${widget.lockedUnits}. Adjust quantities before updating.',
//             ),
//           ),
//         );
//         return;
//       }
//     }

//     final slot = await _pickSlot(context);
//     if (slot == null) return;

//     if (widget.isEditing) {
//       final changes = _buildPlanChanges(draft.selections);
//       await _submitEditUpdate(context, slot, changes);
//       return;
//     }

//     ref.read(selectedSlotProvider.notifier).state = slot;
//     // For now, one slot for all chosen days.
//     Navigator.pushNamed(context, '/subscribe/review');
//   }

//   Future<SlotOption?> _pickSlot(BuildContext context) async {
//     final slots = widget.slots;
//     if (slots.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No available time slots configured.')),
//       );
//       return null;
//     }

//     if (slots.length == 1) {
//       return slots.first;
//     }

//     return await _openSlotPicker(context, slots);
//   }

//   Future<SlotOption?> _openSlotPicker(BuildContext context, List<SlotOption> slots) async {
//     return showModalBottomSheet<SlotOption>(
//       context: context,
//       useSafeArea: true,
//       backgroundColor: Colors.white,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (ctx) {
//         return Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const SizedBox(height: 8),
//             Container(
//               width: 40,
//               height: 4,
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade300,
//                 borderRadius: BorderRadius.circular(99),
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
//               child: Row(
//                 children: [
//                   Text(
//                     'Choose delivery time',
//                     style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 16),
//                   ),
//                 ],
//               ),
//             ),
//             const Divider(height: 1),
//             Flexible(
//               child: ListView.separated(
//                 shrinkWrap: true,
//                 itemCount: slots.length,
//                 separatorBuilder: (_, __) => const Divider(height: 1),
//                 itemBuilder: (_, i) {
//                   final s = slots[i];
//                   final label = _slotDisplay(s);
//                   return ListTile(
//                     title: Text(label.title, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
//                     trailing: const Icon(Icons.chevron_right),
//                     onTap: () => Navigator.pop(ctx, s),
//                   );
//                 },
//               ),
//             ),
//             const SizedBox(height: 8),
//           ],
//         );
//       },
//     );
//   }

//   Future<void> _submitEditUpdate(
//       BuildContext context, SlotOption slot, List<Map<String, dynamic>> days) async {
//     final subId = widget.subscriptionId;
//     if (subId == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Unable to update: missing subscription id.')),
//       );
//       return;
//     }

//     final slotLabel = _slotLabelForRequest(slot);
//     final payload = {
//       'slot_label': slotLabel,
//       'days': days,
//     };

//     try {
//       final api = ApiService();
//       final resp = await api.patch('/api/subscriptions/$subId/plan/', payload);
//       if (!mounted) return;

//       if (resp.statusCode >= 200 && resp.statusCode < 300) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Subscription updated successfully.')),
//         );
//         Navigator.of(context).pop(true);
//       } else {
//         String message = 'Failed to update subscription.';
//         try {
//           final data = jsonDecode(resp.body);
//           if (data is Map && data['detail'] != null) {
//             message = data['detail'].toString();
//           }
//         } catch (_) {}
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(message)),
//         );
//       }
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error updating subscription: $e')),
//       );
//     }
//   }

//   List<Map<String, dynamic>> _buildPlanChanges(Map<String, int> current) {
//     final original = widget.originalSelections;
//     final keys = <String>{...original.keys, ...current.keys};
//     final changes = <Map<String, dynamic>>[];
//     for (final key in keys) {
//       final origQty = original[key] ?? 0;
//       final newQty = current[key] ?? 0;
//       if (origQty != newQty) {
//         changes.add({'date': key, 'qty': newQty});
//       }
//     }
//     return changes;
//   }

//   String _slotLabelForRequest(SlotOption slot) {
//     final label = slot.slotLabel.trim();
//     if (label.isNotEmpty) return label;
//     if (slot.slotStart.isNotEmpty && slot.slotEnd.isNotEmpty) {
//       try {
//         final st = DateTime.parse(slot.slotStart);
//         final en = DateTime.parse(slot.slotEnd);
//         final fmt = DateFormat('HH:mm');
//         return '${fmt.format(st)}-${fmt.format(en)}';
//       } catch (_) {}
//     }
//     final display = _slotDisplay(slot);
//     if (display.subtitle != null && display.subtitle!.trim().isNotEmpty) {
//       return display.subtitle!;
//     }
//     return display.title;
//   }

//   /// Compute a nice display for a slot.
//   _SlotLabel _slotDisplay(SlotOption s) {
//     String? niceRange;
//     try {
//       final st = DateTime.parse(s.slotStart);
//       final en = DateTime.parse(s.slotEnd);
//       final tf = DateFormat('h:mm a');
//       niceRange = '${tf.format(st)} – ${tf.format(en)}';
//     } catch (_) {
//       niceRange = null;
//     }
//     if (s.slotLabel.trim().isNotEmpty && niceRange != null) {
//       return _SlotLabel(title: s.slotLabel.trim(), subtitle: niceRange);
//     }
//     if (s.slotLabel.trim().isNotEmpty) {
//       return _SlotLabel(title: s.slotLabel.trim());
//     }
//     return _SlotLabel(title: niceRange ?? 'Slot');
//   }
// }

// // ── Month grid with MON-first weekday header ──────────────────
// class _MonthGrid extends StatelessWidget {
//   const _MonthGrid({
//     required this.monthAnchor,
//     required this.inRange,
//     required this.isHoliday,
//     required this.sundaySelectable,
//     required this.today,
//     required this.selections,
//     required this.onDayTap,
//     required this.onDayLongPress,
//   });

//   final DateTime monthAnchor;
//   final bool Function(DateTime) inRange;
//   final bool Function(DateTime) isHoliday;
//   final bool sundaySelectable;
//   final DateTime today;
//   final Map<String, int> selections;
//   final void Function(DateTime day) onDayTap;
//   final void Function(DateTime day) onDayLongPress;

//   String _key(DateTime d) =>
//       DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));

//   int _daysInMonth(DateTime m) {
//     final firstOfNext = DateTime(m.year, m.month + 1, 1);
//     return firstOfNext.subtract(const Duration(days: 1)).day;
//   }

//   /// Monday-first: Mon=1 -> 0, Tue=2 -> 1, ..., Sun=7 -> 6
//   int _leadingBlanksMondayFirst(DateTime m) {
//     final first = DateTime(m.year, m.month, 1);
//     return (first.weekday + 6) % 7;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final monthTitle = DateFormat('MMMM yyyy').format(monthAnchor);
//     final days = _daysInMonth(monthAnchor);
//     final lead = _leadingBlanksMondayFirst(monthAnchor);
//     final totalCells = lead + days;
//     final rows = (totalCells / 7.0).ceil();
//     final cells = rows * 7;

//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.only(top: 8, bottom: 4),
//           child: Text(
//             monthTitle,
//             style: GoogleFonts.dmSans(
//               fontSize: 14,
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//         ),
//         // Weekday header: Mon..Sun
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
//           child: Row(
//             children: const [
//               _Weekday('Mon'),
//               _Weekday('Tue'),
//               _Weekday('Wed'),
//               _Weekday('Thu'),
//               _Weekday('Fri'),
//               _Weekday('Sat'),
//               _Weekday('Sun'),
//             ],
//           ),
//         ),
//         Expanded(
//           child: Padding(
//             padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
//             child: GridView.builder(
//               physics: const NeverScrollableScrollPhysics(),
//               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 7,
//                 mainAxisSpacing: 4,
//                 crossAxisSpacing: 4,
//                 childAspectRatio: 1,
//               ),
//               itemCount: cells,
//               itemBuilder: (_, i) {
//                 final isBlank = i < lead || i >= lead + days;
//                 if (isBlank) return const SizedBox.shrink();

//                 final dayNum = i - lead + 1;
//                 final d = DateTime(monthAnchor.year, monthAnchor.month, dayNum);

//                 final isToday = d.year == today.year &&
//                     d.month == today.month &&
//                     d.day == today.day;

//                 final disabled = !inRange(d) ||
//                     (!sundaySelectable && d.weekday == DateTime.sunday) ||
//                     isToday; // today's date not selectable; holidays are selectable

//                 final selected = selections.containsKey(_key(d));
//                 final qty = selections[_key(d)] ?? 0;

//                 return _DayCell(
//                   date: d,
//                   disabled: disabled,
//                   selected: selected,
//                   qty: qty,
//                   isToday: isToday,
//                   isHoliday: isHoliday(d),
//                   onTap: () => disabled ? null : onDayTap(d),
//                   onLongPress: () => disabled ? null : onDayLongPress(d),
//                 );
//               },
//               shrinkWrap: true,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _Weekday extends StatelessWidget {
//   const _Weekday(this.text, {super.key});
//   final String text;
//   @override
//   Widget build(BuildContext context) {
//     return Expanded(
//       child: Center(
//         child: Text(
//           text,
//           style: GoogleFonts.dmSans(
//             fontSize: 11,
//             color: Colors.grey[700],
//             fontWeight: FontWeight.w700,
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _DayCell extends StatelessWidget {
//   const _DayCell({
//     required this.date,
//     required this.disabled,
//     required this.selected,
//     required this.qty,
//     required this.isToday,
//     required this.isHoliday,
//     required this.onTap,
//     required this.onLongPress,
//   });

//   final DateTime date;
//   final bool disabled;
//   final bool selected;
//   final int qty;
//   final bool isToday;
//   final bool isHoliday;
//   final VoidCallback onTap;
//   final VoidCallback onLongPress;

//   @override
//   Widget build(BuildContext context) {
//     final bg = selected ? const Color(0xFF54A079) : Colors.white;
//     final border = disabled
//         ? Colors.grey.shade300
//         : (selected ? const Color(0xFF54A079) : Colors.grey.shade300);
//     final Color fg;
//     if (disabled) {
//       fg = Colors.grey;
//     } else if (selected) {
//       fg = Colors.white;
//     } else if (isHoliday) {
//       fg = Colors.red[700] ?? Colors.red;
//     } else {
//       fg = Colors.black87;
//     }

//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         onTap: disabled ? null : onTap,
//         onLongPress: disabled ? null : onLongPress,
//         borderRadius: BorderRadius.circular(8),
//         child: Container(
//           decoration: BoxDecoration(
//             color: bg,
//             borderRadius: BorderRadius.circular(8),
//             border: Border.all(color: border),
//           ),
//           padding: const EdgeInsets.all(4),
//           child: Stack(
//             children: [
//               Align(
//                 alignment: Alignment.topRight,
//                 child: Text(
//                   '${date.day}',
//                   style: GoogleFonts.dmSans(
//                     fontSize: 12,
//                     fontWeight: FontWeight.w700,
//                     color: fg,
//                   ),
//                 ),
//               ),
//               if (isToday)
//                 Align(
//                   alignment: Alignment.topLeft,
//                   child: Container(
//                     margin: const EdgeInsets.all(4),
//                     width: 5,
//                     height: 5,
//                     decoration: BoxDecoration(
//                       color: selected ? Colors.green : Colors.orange,
//                       shape: BoxShape.circle,
//                     ),
//                   ),
//                 ),
//               if (qty > 0)
//                 Align(
//                   alignment: Alignment.bottomCenter,
//                   child: Container(
//                     padding:
//                         const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                     decoration: BoxDecoration(
//                       color: selected ? Colors.white : const Color(0xFF54A079),
//                       borderRadius: BorderRadius.circular(10),
//                       border: selected
//                           ? Border.all(color: const Color(0xFF54A079))
//                           : null,
//                     ),
//                     child: Text(
//                       'x$qty',
//                       style: GoogleFonts.dmSans(
//                         fontSize: 10,
//                         fontWeight: FontWeight.w800,
//                         color:
//                             selected ? const Color(0xFF54A079) : Colors.white,
//                       ),
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ── Footer: Qty + Menu + Add-ons + Totals + Continue ─────────
// class _Footer extends StatelessWidget {
//   const _Footer({
//     required this.focusedDate,
//     required this.draft,
//     required this.menuPlan,
//     required this.isHolidayFocused,
//     required this.maxPerDay,
//     // add-ons
//     required this.addonsByDate,
//     required this.addonsCatalog,
//     required this.addonsLocked,
//     required this.onOpenAddons,
//     // qty + navigation
//     required this.onQtyChanged,
//     required this.buttonLabel,
//     required this.isEditing,
//     required this.lockedUnits,
//     required this.unitsValid,
//     required this.onContinue,
//   });

//   final DateTime? focusedDate;
//   final SubscriptionDraft draft;
//   final Map<String, List<String>> menuPlan;
//   final bool isHolidayFocused;
//   final int maxPerDay;

//   // add-ons
//   final Map<String, Map<String, int>> addonsByDate;
//   final List<AddonItem> addonsCatalog;
//   final bool addonsLocked;
//   final VoidCallback? onOpenAddons;

//   // actions
//   final ValueChanged<int> onQtyChanged;
//   final String buttonLabel;
//   final bool isEditing;
//   final int? lockedUnits;
//   final bool unitsValid;
//   final VoidCallback? onContinue;

//   String _key(DateTime d) =>
//       DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));

//   int _addonsCountFor(String k) {
//     final m = addonsByDate[k];
//     if (m == null || m.isEmpty) return 0;
//     return m.values.fold(0, (a, b) => a + b);
//   }

//   double _addonsTotalFor(String k) {
//     final m = addonsByDate[k];
//     if (m == null || m.isEmpty) return 0;
//     double sum = 0;
//     for (final e in m.entries) {
//       final meta = addonsCatalog.firstWhere(
//         (a) => a.id == e.key,
//         orElse: () => const AddonItem(id: '_', name: '_', price: 0),
//       );
//       sum += meta.price * e.value;
//     }
//     return sum;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final hasFocus = focusedDate != null;
//     final k = hasFocus ? _key(focusedDate!) : null;
//     final qty = hasFocus ? (draft.selections[k] ?? draft.defaultQty) : 0;
//     final menu =
//         hasFocus ? (menuPlan[k] ?? const <String>[]) : const <String>[];
//     final title = hasFocus
//         ? DateFormat('EEE, d MMM').format(focusedDate!)
//         : (isEditing ? 'Pick a date to adjust' : 'Select a date');

//     final addonsCount = hasFocus ? _addonsCountFor(k!) : 0;
//     final addonsTotal = hasFocus ? _addonsTotalFor(k!) : 0.0;

//     // Button payable = subscription grand total + add-ons for the focused day only
//     final payable = (draft.grandTotal + (hasFocus ? addonsTotal : 0))
//         .clamp(0, double.infinity);

//     return Container(
//       decoration: const BoxDecoration(
//         color: Color(0xFFFDFDFE),
//         border: Border(top: BorderSide(color: Color(0x11000000))),
//         boxShadow: [
//           BoxShadow(
//             color: Color(0x14000000),
//             blurRadius: 8,
//             offset: Offset(0, -2),
//           ),
//         ],
//       ),
//       child: SafeArea(
//         top: false,
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // Card: title + qty + add-ons + (no Clear) + menu
//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFFFFFFF),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: const Color(0xFFE5E7EB)),
//                 ),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     // Title + qty + Add-ons chip  (Clear removed)
//                     Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             title,
//                             style: GoogleFonts.dmSans(
//                               fontSize: 14,
//                               fontWeight: FontWeight.w800,
//                             ),
//                           ),
//                         ),
//                         if (hasFocus && !isHolidayFocused)
//                           _QtyInline(
//                             enabled: hasFocus,
//                             qty: qty,
//                             max: maxPerDay,
//                             onChanged: onQtyChanged,
//                           ),
//                         if (hasFocus && !isHolidayFocused)
//                           const SizedBox(width: 8),
//                       ],
//                     ),
//                     const SizedBox(height: 6),

//                     // When a holiday is focused, show a Holiday message instead of qty/menu
//                     if (hasFocus && isHolidayFocused)
//                       Padding(
//                         padding: const EdgeInsets.only(bottom: 4, top: 2),
//                         child: Text(
//                           'Holiday',
//                           style: GoogleFonts.dmSans(
//                             fontSize: 12,
//                             fontWeight: FontWeight.w700,
//                             color: Colors.red[700],
//                           ),
//                         ),
//                       )
//                     else ...[
//                       // Menu label
//                       Align(
//                         alignment: Alignment.centerLeft,
//                         child: Text(
//                           'Menu',
//                           style: GoogleFonts.dmSans(
//                             fontSize: 12,
//                             fontWeight: FontWeight.w700,
//                             color: Colors.grey[800],
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 4),

//                       hasFocus
//                           ? (menu.isEmpty
//                               ? Padding(
//                                   padding: const EdgeInsets.only(bottom: 4),
//                                   child: Text(
//                                     'Menu not set for this date.',
//                                     style: GoogleFonts.dmSans(
//                                       fontSize: 12,
//                                       color: Colors.grey[700],
//                                     ),
//                                   ),
//                                 )
//                               : ConstrainedBox(
//                                   constraints:
//                                       const BoxConstraints(maxHeight: 75),
//                                   child: SingleChildScrollView(
//                                     child: Row(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         Expanded(
//                                           child: Wrap(
//                                             spacing: 8,
//                                             runSpacing: 8,
//                                             children: menu
//                                                 .map((line) => _menuPill(line))
//                                                 .toList(),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ))
//                           : Text(
//                               isEditing
//                                   ? 'Select a date above to adjust quantities or add days.'
//                                   : 'Select a date above to set quantity and view the menu.',
//                               style: GoogleFonts.dmSans(
//                                 fontSize: 12,
//                                 color: Colors.grey[700],
//                               ),
//                             ),
//                     ],
//                   ],
//                 ),
//               ),

//               const SizedBox(height: 10),

//               if (isEditing && lockedUnits != null && !unitsValid)
//                 Padding(
//                   padding: const EdgeInsets.only(bottom: 6),
//                   child: Text(
//                     'Keep total units at $lockedUnits to update the schedule.',
//                     style: GoogleFonts.dmSans(
//                       fontSize: 12,
//                       fontWeight: FontWeight.w700,
//                       color: Colors.red[700],
//                     ),
//                   ),
//                 ),

//               // Totals Bar (no Payable text here)
//               Row(
//                 children: [
//                   Expanded(
//                     child: Wrap(
//                       spacing: 10,
//                       runSpacing: 4,
//                       crossAxisAlignment: WrapCrossAlignment.center,
//                       children: [
//                         _pill('${draft.totalUnits} unit(s)'),
//                         _pill('Total ₹ ${draft.itemTotal.toStringAsFixed(0)}'),
//                         if (draft.discount > 0)
//                           _pill(
//                             'Discount ₹ ${draft.discount.toStringAsFixed(0)}',
//                             bg: const Color(0xFFE9F7EF),
//                             fg: const Color(0xFF2E7D32),
//                           ),
//                         _pill('Payable ₹ ${(draft.itemTotal - draft.discount).toStringAsFixed(0)}'),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   ElevatedButton(
//                     onPressed: onContinue,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: onContinue == null
//                           ? Colors.grey
//                           : const Color(0xFF54A079),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 10,
//                       ),
//                     ),
//                     child: Text(
//                       buttonLabel,
//                       style: GoogleFonts.dmSans(
//                         fontWeight: FontWeight.w700,
//                         color: Colors.white,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
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

//   Widget _menuPill(String text) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF7F8FA),
//         borderRadius: BorderRadius.circular(999),
//         border: Border.all(color: const Color(0xFFE5E7EB)),
//       ),
//       child: Text(
//         text,
//         style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF2D3748)),
//       ),
//     );
//   }
// }

// class _QtyInline extends StatefulWidget {
//   final bool enabled;
//   final int qty;
//   final int max;
//   final ValueChanged<int> onChanged;

//   const _QtyInline({
//     required this.enabled,
//     required this.qty,
//     required this.max,
//     required this.onChanged,
//   });

//   @override
//   State<_QtyInline> createState() => _QtyInlineState();
// }

// class _QtyInlineState extends State<_QtyInline> {
//   late int _qty;

//   @override
//   void initState() {
//     super.initState();
//     _qty = widget.qty;
//   }

//   @override
//   void didUpdateWidget(covariant _QtyInline oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (oldWidget.qty != widget.qty) {
//       _qty = widget.qty;
//     }
//   }

//   void _bump(int delta) {
//     if (!widget.enabled) return;
//     final next = (_qty + delta).clamp(0, widget.max);
//     setState(() => _qty = next);
//     widget.onChanged(next);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final atMin = _qty <= 0;
//     final atMax = _qty >= widget.max && widget.max > 0;
//     return Row(
//       children: [
//         _btn(Icons.remove, widget.enabled && !atMin ? () => _bump(-1) : null),
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 8.0),
//           child: Text(
//             widget.enabled ? '$_qty' : '-',
//             style: GoogleFonts.dmSans(
//               fontSize: 16,
//               fontWeight: FontWeight.w800,
//             ),
//           ),
//         ),
//         _btn(Icons.add, widget.enabled && !atMax ? () => _bump(1) : null),
//       ],
//     );
//   }

//   Widget _btn(IconData icon, VoidCallback? onTap) {
//     return InkResponse(
//       onTap: onTap,
//       radius: 18,
//       child: Container(
//         padding: const EdgeInsets.all(6),
//         decoration: BoxDecoration(
//           border: Border.all(color: Colors.grey.shade400),
//           color: onTap == null ? Colors.grey.shade200 : Colors.white,
//           borderRadius: BorderRadius.circular(6),
//         ),
//         child: Icon(icon, size: 16),
//       ),
//     );
//   }
// }

// /// Add-ons chip in footer (compact)
// class _AddonsChip extends StatelessWidget {
//   const _AddonsChip({
//     required this.enabled,
//     required this.count,
//     required this.total,
//     required this.onTap,
//     required this.locked,
//   });

//   final bool enabled;
//   final int count;
//   final double total;
//   final VoidCallback? onTap;
//   final bool locked;

//   @override
//   Widget build(BuildContext context) {
//     final has = count > 0;
//     final text = locked
//         ? 'Add-ons (Locked)'
//         : has
//             ? 'Add-ons ($count • ₹${total.toStringAsFixed(0)})'
//             : 'Add-ons';
//     final bg = locked
//         ? const Color(0xFFF2F2F2)
//         : has
//             ? const Color(0xFFE9F7EF)
//             : const Color(0xFFF4F6F8);
//     final fg = locked
//         ? Colors.grey
//         : has
//             ? const Color(0xFF2E7D32)
//             : const Color(0xFF2D3748);

//     return InkWell(
//       borderRadius: BorderRadius.circular(999),
//       onTap: enabled ? onTap : null,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//         decoration: BoxDecoration(
//           color: bg,
//           borderRadius: BorderRadius.circular(999),
//           border: Border.all(
//             color: has ? const Color(0xFFBEE3BE) : const Color(0xFFE5E7EB),
//           ),
//         ),
//         child: Text(
//           text,
//           style: GoogleFonts.dmSans(fontSize: 12, color: fg),
//         ),
//       ),
//     );
//   }
// }

// /// Tiny stepper used inside add-ons bottom sheet
// class _QtyMini extends StatelessWidget {
//   const _QtyMini({required this.qty, required this.onChanged, this.max = 20});
//   final int qty;
//   final int max;
//   final ValueChanged<int> onChanged;

//   @override
//   Widget build(BuildContext context) {
//     final atMin = qty <= 0;
//     final atMax = qty >= max;
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         _btn(Icons.remove, !atMin ? () => onChanged(qty - 1) : null),
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 8.0),
//           child: Text(
//             '$qty',
//             style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
//           ),
//         ),
//         _btn(Icons.add, !atMax ? () => onChanged(qty + 1) : null),
//       ],
//     );
//   }

//   Widget _btn(IconData icon, VoidCallback? onTap) {
//     return InkResponse(
//       onTap: onTap,
//       radius: 18,
//       child: Container(
//         padding: const EdgeInsets.all(6),
//         decoration: BoxDecoration(
//           border: Border.all(color: Colors.grey.shade400),
//           color: onTap == null ? Colors.grey.shade200 : Colors.white,
//           borderRadius: BorderRadius.circular(6),
//         ),
//         child: Icon(icon, size: 16),
//       ),
//     );
//   }
// }

// class _SlotLabel {
//   final String title;
//   final String? subtitle;
//   _SlotLabel({required this.title, this.subtitle});
// }
