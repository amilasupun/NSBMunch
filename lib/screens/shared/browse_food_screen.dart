import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nsbmunch/core/constants/app_colors.dart';
import 'package:nsbmunch/models/menu_item_model.dart';
import 'package:nsbmunch/models/cart_item_model.dart';

class BrowseFoodScreen extends StatefulWidget {
  final List<CartItem> cart;
  final VoidCallback onCartUpdate;

  const BrowseFoodScreen({
    super.key,
    required this.cart,
    required this.onCartUpdate,
  });

  @override
  State<BrowseFoodScreen> createState() => _BrowseFoodScreenState();
}

class _BrowseFoodScreenState extends State<BrowseFoodScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedCat = 'All';
  String? _expandedId;

  Stream<List<MenuItem>> _getAllItems() {
    return FirebaseFirestore.instance
        .collection('menu_items')
        .snapshots()
        .map((s) => s.docs.map((d) => MenuItem.fromDoc(d)).toList());
  }

  // Allow any shop items
  void _addToCart(MenuItem item) {
    final existing = widget.cart.where((c) => c.menuItem.id == item.id);
    if (existing.isNotEmpty) {
      existing.first.quantity++;
    } else {
      widget.cart.add(CartItem(menuItem: item));
    }
    widget.onCartUpdate();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} added to cart'),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _toggleExpand(String itemId) {
    setState(() {
      _expandedId = _expandedId == itemId ? null : itemId;
    });
  }

  List<MenuItem> _filter(List<MenuItem> all) {
    return all.where((item) {
      final matchCat = _selectedCat == 'All' || item.category == _selectedCat;
      final q = _searchQuery.toLowerCase();
      final matchQ =
          q.isEmpty ||
          item.name.toLowerCase().contains(q) ||
          item.shopName.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q);
      return matchCat && matchQ;
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.black,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Find foods or shop',
              hintStyle: const TextStyle(color: AppColors.textGrey),
              prefixIcon: const Icon(Icons.search, color: AppColors.textGrey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textGrey),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),

        // Category filter
        Container(
          color: Colors.black,
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: kFoodCategories.length,
            itemBuilder: (ctx, i) {
              final cat = kFoodCategories[i];
              final selected = cat == _selectedCat;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedCat = cat;
                  _expandedId = null;
                }),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.green : const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppColors.green : AppColors.border,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.textGrey,
                      fontSize: 12,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Food list
        Expanded(
          child: StreamBuilder<List<MenuItem>>(
            stream: _getAllItems(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.green),
                );
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snap.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final filtered = _filter(snap.data ?? []);

              if (filtered.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 60,
                        color: AppColors.textGrey,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No items found.',
                        style: TextStyle(color: AppColors.textGrey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final item = filtered[i];
                  final isExpanded = _expandedId == item.id;
                  return _FoodCard(
                    item: item,
                    isExpanded: isExpanded,
                    onTap: () => _toggleExpand(item.id),
                    onAddTap: () => _addToCart(item),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FoodCard extends StatelessWidget {
  final MenuItem item;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onAddTap;

  const _FoodCard({
    required this.item,
    required this.isExpanded,
    required this.onTap,
    required this.onAddTap,
  });
  // ignore
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded ? AppColors.green : AppColors.border,
            width: isExpanded ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: item.imageUrl.isNotEmpty
                  ? Image.network(
                      item.imageUrl,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, prog) {
                        if (prog == null) return child;
                        return Container(
                          height: 160,
                          color: const Color(0xFF111111),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.green,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => _Placeholder(),
                    )
                  : _Placeholder(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (item.shopName.isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons.storefront,
                                size: 12,
                                color: AppColors.textGrey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.shopName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Rs. ${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      GestureDetector(
                        onTap: onAddTap,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white.withValues(alpha: 0.45),
                            size: 22,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(
                      color: Colors.white.withValues(alpha: 0.1),
                      height: 12,
                    ),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.55),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: isExpanded && item.description.isNotEmpty
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }
}

//ignore part
class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 160,
    width: double.infinity,
    color: const Color(0xFF111111),
    child: const Icon(Icons.fastfood, color: AppColors.green, size: 60),
  );
}
