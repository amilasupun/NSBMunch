import 'package:flutter/material.dart';
import 'package:nsbmunch/core/constants/app_colors.dart';
import 'package:nsbmunch/models/cart_item_model.dart';
import 'package:nsbmunch/screens/student/check_order_page.dart';
import 'package:nsbmunch/screens/student/schedule_order_page.dart';

class CartScreen extends StatefulWidget {
  final List<CartItem> cart;

  const CartScreen({super.key, required this.cart});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

// Cart screen for students
class _CartScreenState extends State<CartScreen> {
  Map<String, List<CartItem>> get _groupedByShop {
    final Map<String, List<CartItem>> grouped = {};
    for (final item in widget.cart) {
      final shopId = item.menuItem.shopId;
      grouped.putIfAbsent(shopId, () => []).add(item);
    }
    return grouped;
  }

  // Grand total across all items in the cart
  double get _grandTotal =>
      widget.cart.fold(0.0, (sum, c) => sum + c.totalPrice);

  void _increase(CartItem item) => setState(() => item.quantity++);

  void _decrease(CartItem item) => setState(() {
    if (item.quantity > 1) {
      item.quantity--;
    } else {
      widget.cart.remove(item);
    }
  });
  // Navigate to order confirmation page
  void _goToOrder() {
    if (widget.cart.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckOrderPage(cart: widget.cart)),
    ).then((_) => setState(() {}));
  }

  // Navigate to schedule order page
  void _goToSchedule() {
    if (widget.cart.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScheduleOrderPage(cart: widget.cart)),
    ).then((_) => setState(() {}));
  }

  // Main build method
  @override
  Widget build(BuildContext context) {
    final grouped = _groupedByShop;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Cart',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: widget.cart.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 60,
                    color: AppColors.textGrey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Your cart is empty.',
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Info banner
                if (grouped.length > 1)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.green),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${grouped.length} shops — separate orders will be created for each shop.',
                            style: const TextStyle(
                              color: AppColors.green,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Items grouped by shop
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: grouped.entries.map((entry) {
                      final shopItems = entry.value;
                      final shopName = shopItems.first.menuItem.shopName;
                      final shopTotal = shopItems.fold(
                        0.0,
                        (s, c) => s + c.totalPrice,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Shop header
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.green),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.storefront,
                                      color: AppColors.green,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      shopName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Rs. ${shopTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppColors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Items under this shop
                          ...shopItems.map(
                            (cartItem) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cartItem.menuItem.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'Rs. ${cartItem.menuItem.price.toStringAsFixed(2)} x ${cartItem.quantity}',
                                          style: const TextStyle(
                                            color: AppColors.textGrey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          'Rs. ${cartItem.totalPrice.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: AppColors.green,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      _QtyBtn(
                                        icon: Icons.remove,
                                        onTap: () => _decrease(cartItem),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        child: Text(
                                          '${cartItem.quantity}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      _QtyBtn(
                                        icon: Icons.add,
                                        onTap: () => _increase(cartItem),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                // Bottom bar
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Grand total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Grand Total',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (grouped.length > 1)
                                Text(
                                  '${grouped.length} separate orders',
                                  style: const TextStyle(
                                    color: AppColors.textGrey,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            'Rs. ${_grandTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.green,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.green,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _goToOrder,
                              icon: const Icon(
                                Icons.flash_on,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                'Order Now',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF1A237E),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _goToSchedule,
                              icon: const Icon(
                                Icons.schedule,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                'Schedule',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// Quantity adjustment button widget
class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: AppColors.green, size: 18),
    ),
  );
}
