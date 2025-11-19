import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outlet_app/constants.dart';
import 'package:outlet_app/core/utils/url_utils.dart';
import 'package:outlet_app/providers/category_provider.dart';

import '../../providers/menu_provider.dart';

Color _opacity(Color color, double opacity) {
  final clamped = opacity.clamp(0.0, 1.0);
  final alpha = (clamped * 255).roundToDouble();
  return color.withValues(alpha: alpha);
}

class ManageMenuScreen extends ConsumerStatefulWidget {
  const ManageMenuScreen({super.key});

  @override
  ConsumerState<ManageMenuScreen> createState() => _ManageMenuScreenState();
}

class _ManageMenuScreenState extends ConsumerState<ManageMenuScreen> {
  static const double _fabSize = 72;
  Offset? _fabPosition;
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      final next = _searchController.text.trim();
      if (next != _searchQuery && mounted) {
        setState(() => _searchQuery = next);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Offset _clampToBounds(Offset offset, Size size, EdgeInsets padding) {
    const double minX = 16.0;
    final double maxX = size.width - _fabSize - 16.0;
    final double minY = padding.top + 16.0;
    final double maxY = size.height - padding.bottom - _fabSize - 16.0;
    return Offset(
      offset.dx.clamp(minX, maxX),
      offset.dy.clamp(minY, maxY),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuState = ref.watch(menuProvider);
    final menuNotifier = ref.read(menuProvider.notifier);
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    const accentColor = Color(0xFF54A079);

    final lowerQuery = _searchQuery.toLowerCase();
    final visibleItems = menuState.filteredItems.where((item) {
      if (lowerQuery.isEmpty) return true;
      final name = (item['name'] ?? '').toString().toLowerCase();
      return name.contains(lowerQuery);
    }).toList();

    _fabPosition ??= Offset(
      size.width - _fabSize - 16,
      size.height - _fabSize - padding.bottom - 16,
    );

    _fabPosition = _clampToBounds(_fabPosition!, size, padding);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Stack(
        children: [
          SafeArea(
            child: menuState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: CustomScrollView(
                      slivers: <Widget>[
                        // SliverToBoxAdapter(
                        //   child: Padding(
                        //     padding: const EdgeInsets.only(top: 8.0, bottom: 4),
                        //     child: _MenuHeaderCard(
                        //       accentColor: accentColor,
                        //       totalItems: menuState.items.length,
                        //       totalCategories: totalCategories,
                        //     ),
                        //   ),
                        // ),
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FindBar(
                                controller: _searchController,
                                hintText: 'Find dishes or beverages...',
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _SliverAppBarDelegate(
                            minHeight: 82,
                            maxHeight: 82,
                            child: Container(
                              color: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding:
                                        EdgeInsets.only(top: 12.0, bottom: 8.0),
                                    child: Text(
                                      "Category",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  CategorySelectionWidget(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              _SectionTitle(
                                title: 'Menu Items',
                                subtitle: _searchQuery.isEmpty
                                    ? 'Showing ${visibleItems.length} items'
                                    : '“$_searchQuery” · ${visibleItems.length} result${visibleItems.length == 1 ? '' : 's'}',
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                        if (visibleItems.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyMenuState(
                              onCreateItem: () => Navigator.pushNamed(
                                context,
                                "/add-item",
                                arguments: {
                                  "is_edit_mode": false,
                                  "product_id": null,
                                },
                              ).then((_) => ref.invalidate(menuProvider)),
                            ),
                          )
                        else
                          SliverPadding(
                            padding:
                                const EdgeInsets.only(bottom: 32.0, top: 4.0),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 0.78,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = visibleItems[index];
                                  return ProductGridItem(
                                    item: item,
                                    accentColor: accentColor,
                                    onEdit: () {
                                      Navigator.pushNamed(
                                        context,
                                        "/add-item",
                                        arguments: {
                                          "is_edit_mode": true,
                                          "product_id": item["id"],
                                        },
                                      ).then((_) {
                                        ref.invalidate(
                                            menuProvider); // ✅ Refresh Menu List
                                      });
                                    },
                                    onDelete: () {
                                      menuNotifier.deleteItem(item["id"]);
                                    },
                                  );
                                },
                                childCount: visibleItems.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          Positioned(
            left: _fabPosition!.dx,
            top: _fabPosition!.dy,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  final tentative = _fabPosition! + details.delta;
                  _fabPosition = _clampToBounds(tentative, size, padding);
                });
              },
              child: Tooltip(
                message: 'Drag to reposition',
                child: Container(
                  width: _fabSize,
                  height: _fabSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: SpeedDial(
                        icon: Icons.add,
                        activeIcon: Icons.close,
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        children: [
                          SpeedDialChild(
                            child: const Icon(Icons.category),
                            backgroundColor: Colors.white,
                            foregroundColor: accentColor,
                            label: 'New Category',
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                "/add-category",
                                arguments: {
                                  "is_edit_mode": false,
                                  "product_id": null,
                                },
                              ).then((value) {
                                ref.invalidate(
                                    menuProvider); // ✅ Refresh Menu List
                                ref
                                    .read(categoryStateProvider.notifier)
                                    .reset(); // ✅ Reset category form
                              });
                            },
                          ),
                          SpeedDialChild(
                            child: const Icon(Icons.food_bank),
                            foregroundColor: accentColor,
                            backgroundColor: Colors.white,
                            label: 'New Item',
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                "/add-item",
                                arguments: {
                                  "is_edit_mode": false,
                                  "product_id": null,
                                },
                              ).then((value) {
                                ref.invalidate(
                                    menuProvider); // ✅ Refresh Menu List
                                //ref.invalidate(menuItemStateProvider);
                              });
                            },
                          ),
                        ]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ **Grid Item Widget**
class ProductGridItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Color accentColor;

  const ProductGridItem({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.accentColor,
  });

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    } else {
      return "${text.substring(0, maxLength - 3)}...";
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = item['price'];
    final priceLabel = price == null
        ? '—'
        : '₹${double.tryParse(price.toString())?.toStringAsFixed(0) ?? price.toString()}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onEdit,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _MenuImage(
                      imageUrl: (item["display_image"] ?? '').toString(),
                      accentColor: accentColor,
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _opacity(Colors.white, 0.88),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Text(
                          priceLabel,
                          style: GoogleFonts.roboto(
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _truncateText(item["name"]?.toString() ?? 'Untitled', 26),
                    style: GoogleFonts.roboto(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap to edit or use more options',
                    style: GoogleFonts.roboto(
                      fontSize: 11,
                      color: _opacity(Colors.black, 0.5),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _opacity(Colors.white, 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon(Icons.star_outline,
                            //     size: 14, color: accentColor),
                            const SizedBox(width: 4),
                            Text(
                              '',
                              style: GoogleFonts.roboto(
                                fontSize: 11,
                                color: accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit();
                          } else if (value == 'delete') {
                            onDelete();
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Edit item'),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Remove from menu'),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _opacity(Colors.white, 0.04),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.more_horiz,
                              size: 20, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategorySelectionWidget extends ConsumerStatefulWidget {
  const CategorySelectionWidget({super.key});

  @override
  CategorySelectionWidgetState createState() => CategorySelectionWidgetState();
}

class CategorySelectionWidgetState
    extends ConsumerState<CategorySelectionWidget> {
  String? selectedCategoryId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final menuState = ref.read(menuProvider);
      if (menuState.categories.isNotEmpty) {
        setState(() {
          selectedCategoryId = menuState.categories.first["category_id"];
        });
        ref.read(menuProvider.notifier).selectCategory(selectedCategoryId!);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menuState = ref.watch(menuProvider);
    final menuNotifier = ref.read(menuProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(left: 20.0),
      child: SizedBox(
        height: 30,
        child: ListView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          children: menuState.categories.map((category) {
            final bool isSelected =
                selectedCategoryId == category["category_id"];

            return Builder(
              builder: (itemContext) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCategoryId = category["category_id"];
                    });
                    menuNotifier.selectCategory(category["category_id"]);

                    if (!_scrollController.hasClients) return;

                    final renderBox =
                        itemContext.findRenderObject() as RenderBox?;
                    if (renderBox == null) return;

                    final position = renderBox.localToGlobal(Offset.zero);
                    final itemWidth = renderBox.size.width;
                    final screenWidth = MediaQuery.of(context).size.width;
                    final itemCenterX = position.dx + itemWidth / 2;
                    const double shift = 100;

                    if (itemCenterX > screenWidth * (2 / 3)) {
                      _scrollController.animateTo(
                        (_scrollController.offset + shift).clamp(
                            0.0, _scrollController.position.maxScrollExtent),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    } else if (itemCenterX < screenWidth * (1 / 3)) {
                      _scrollController.animateTo(
                        (_scrollController.offset - shift).clamp(
                            0.0, _scrollController.position.maxScrollExtent),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      category["name"] ?? '',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        decoration: isSelected
                            ? TextDecoration.underline
                            : TextDecoration.none,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                        color:
                            isSelected ? const Color(0xFF54A079) : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class FindBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const FindBar({
    super.key,
    required this.controller,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 16,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          prefixIcon:
              const Icon(Icons.search_rounded, color: Color(0xFF6B7280)),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    controller.clear();
                    FocusScope.of(context).unfocus();
                  },
                  icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                ),
          hintText: hintText,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: GoogleFonts.roboto(
          fontSize: 14,
          color: const Color(0xFF111827),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

class _MenuImage extends StatelessWidget {
  final String imageUrl;
  final Color accentColor;

  const _MenuImage({
    required this.imageUrl,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = resolveMediaUrl(imageUrl);
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _opacity(accentColor, 0.15),
              _opacity(accentColor, 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child:
            Icon(Icons.local_cafe, size: 44, color: _opacity(accentColor, 0.7)),
      );
    }

    return Image.network(
      resolvedUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: _opacity(accentColor, 0.05),
        alignment: Alignment.center,
        child: Icon(Icons.broken_image_outlined,
            size: 40, color: _opacity(accentColor, 0.6)),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: _opacity(accentColor, 0.05),
          alignment: Alignment.center,
          child: CircularProgressIndicator(
            value: progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                : null,
            color: accentColor,
            strokeWidth: 2,
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.roboto(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
        const Spacer(),
        if (subtitle != null)
          Text(
            subtitle!,
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: const Color(0xFF6B7280),
            ),
          ),
      ],
    );
  }
}

class _EmptyMenuState extends StatelessWidget {
  final VoidCallback onCreateItem;

  const _EmptyMenuState({required this.onCreateItem});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _opacity(const Color(0xFF54A079), 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_dining,
                size: 52, color: Color(0xFF54A079)),
          ),
          const SizedBox(height: 20),
          Text(
            'No items found',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search or add a new item to your menu.',
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
              color: const Color(0xFF6B7280),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreateItem,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add your first item'),
          ),
        ],
      ),
    );
  }
}
