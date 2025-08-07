import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outlet_app/constants.dart';
import 'package:outlet_app/providers/category_provider.dart';
import '../../providers/menu_provider.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:google_fonts/google_fonts.dart';

class ManageMenuScreen extends ConsumerWidget {
  const ManageMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuState = ref.watch(menuProvider);
    final menuNotifier = ref.read(menuProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      
      floatingActionButton: SpeedDial(
          icon: Icons.add, // FAB icon
          activeIcon: Icons.close, // Icon when SpeedDial is open
          backgroundColor: const Color(0xFF54A079), // FAB background color
          foregroundColor: Colors.white, // FAB icon color
          children: [
            SpeedDialChild(
              child: const Icon(Icons.category),
              backgroundColor: Colors.white70,
              foregroundColor: const Color(0xFF54A079),
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
                  ref.invalidate(menuProvider); // ✅ Refresh Menu List
                  ref.read(categoryStateProvider.notifier).reset(); // ✅ Reset category form
                });
              },
            ),
            SpeedDialChild(
              child: const Icon(Icons.food_bank),
              foregroundColor: const Color(0xFF54A079),
              backgroundColor: Colors.white70,
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
                  ref.invalidate(menuProvider); // ✅ Refresh Menu List
                  //ref.invalidate(menuItemStateProvider);
                });
              },
            ),
          ]),
      body: menuState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: CustomScrollView(
                slivers: <Widget>[
                  const SliverAppBar(
                    automaticallyImplyLeading: false,
                    title: Center(child: Text("Menu")),
                    
                    backgroundColor: Colors.white,
                      pinned: true,
                      floating: true,
                      expandedHeight: 300,
                      bottom: PreferredSize(
                        preferredSize: Size.fromHeight(260),
                        child: Column(
                          children: [
                            FindBar(),
                            Padding(
                              padding: EdgeInsets.only(top: 12.0, bottom: 8.0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Category",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            // ✅ Optimized Category Selection
                            CategorySelectionWidget(),
                          ],
                        ),
                      )),
                  SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = menuState.filteredItems[index];
                        return ProductGridItem(
                          item: item,
                          onEdit: () {
                            Navigator.pushNamed(
                              context,
                              "/add-item",
                              arguments: {
                                "is_edit_mode": true,
                                "product_id": item["id"],
                              },
                            ).then((value) {
                              ref.invalidate(
                                  menuProvider); // ✅ Refresh Menu List
                            });
                          },
                          onDelete: () {
                            menuNotifier.deleteItem(item["id"]);
                          },
                        );
                      },
                      childCount: menuState.filteredItems.length,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _teaCupIcon() {
    return const Icon(Icons.local_cafe, size: 50, color: Colors.grey);
  }
}

/// ✅ **Grid Item Widget**
class ProductGridItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProductGridItem({super.key, 
    required this.item,
    required this.onEdit,
    required this.onDelete,
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
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ✅ Product Image
          SizedBox(
            height: 120,
            width: double.infinity,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10), bottom: Radius.circular(10)),
                child: (item["display_image"] == null ||
                        item["display_image"] == "")
                    ? _teaCupIcon()
                    : Image.network(
                        BASE_URL + item["display_image"],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
              ),
            ),
          ),

          // ✅ Product Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _truncateText(item["name"], 15),
                      textAlign: TextAlign.left,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      "₹${item["price"]}",
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              // ✅ Single "+" Icon with Popup Menu
              PopupMenuButton<String>(
                // icon: const Icon(Icons.add_rounded , color: Colors.black), // ✅ "+" icon
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                onSelected: (String value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    "+",
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _teaCupIcon() {
    return const Icon(Icons.local_cafe, size: 50, color: Colors.grey);
  }
}

class CategorySelectionWidget extends ConsumerStatefulWidget {
  const CategorySelectionWidget({super.key});

  @override
  _CategorySelectionWidgetState createState() =>
      _CategorySelectionWidgetState();
}

class _CategorySelectionWidgetState
    extends ConsumerState<CategorySelectionWidget> {
  String? selectedCategoryId;

  @override
  void initState() {
    super.initState();
    // ✅ Ensure the default selected category is "All"
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
  Widget build(BuildContext context) {
    final menuState = ref.watch(menuProvider);
    final menuNotifier = ref.read(menuProvider.notifier);

    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: menuState.categories.map((category) {
          bool isSelected = selectedCategoryId == category["category_id"];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedCategoryId =
                      category["category_id"]; // ✅ Update local state
                });
                menuNotifier.selectCategory(
                    category["category_id"]); // ✅ Update provider
              },
              child: Column(
                children: [
                  AnimatedContainer(
                    duration:
                        const Duration(milliseconds: 300), // ✅ Smooth animation
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF54A079)
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF54A079)
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: category["icon"] == ""
                          ? Icon(
                              Icons.emoji_food_beverage,
                              color: isSelected ? Colors.white : Colors.black,
                              size: 40,
                            )
                          : SizedBox(
                              height: 40,
                              width: 40,
                              child: Image.network(
                                  "$BASE_URL${category["icon"]}",
                                  fit: BoxFit.cover),
                            ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: 70,
                    child: Text(
                      category["name"],
                      textAlign: TextAlign.center,
                      softWrap: true,
                      overflow: TextOverflow.visible, // Ensure wrapping
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color:
                            isSelected ? const Color(0xFF54A079) : Colors.black,
                      ),
                      // TextStyle(
                      //   fontSize: 12.0,
                      //   fontWeight: FontWeight.bold,
                      //   color: isSelected ? const Color(0xFF54A079) : Colors.black,
                      // ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class FindBar extends StatelessWidget {
  const FindBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: const Row(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              child: Icon(Icons.search_outlined, color: Colors.black87),
            ),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Find your Cravings here',
                  border: InputBorder.none,
                ),
                style: TextStyle(
                    fontSize: 12.0,
                    color: Colors.black,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
