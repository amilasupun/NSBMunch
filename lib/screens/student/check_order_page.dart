import 'package:flutter/material.dart';
import 'package:nsbmunch/core/constants/app_colors.dart';
import 'package:nsbmunch/core/services/order_service.dart';
import 'package:nsbmunch/core/services/payment_service.dart';
import 'package:nsbmunch/models/cart_item_model.dart';
import 'package:nsbmunch/models/payment_card_model.dart';
import 'package:nsbmunch/models/bank_account_model.dart';
import 'package:nsbmunch/screens/student/payment_details_screen.dart';

// check order page
class CheckOrderPage extends StatefulWidget {
  final List<CartItem> cart;

  const CheckOrderPage({super.key, required this.cart});

  @override
  State<CheckOrderPage> createState() => _CheckOrderPageState();
}

class _CheckOrderPageState extends State<CheckOrderPage> {
  final _orderService = OrderService();
  final _paymentService = PaymentService();

  int _pickupHour;
  int _pickupMinute;

  bool _loading = false;
  PaymentCard? _activeCard;
  bool _cardLoaded = false;

  _CheckOrderPageState()
    : _pickupHour = TimeOfDay.now().hour,
      _pickupMinute = (() {
        final m = ((TimeOfDay.now().minute ~/ 5) + 1) * 5;
        return m >= 60 ? 0 : m;
      })();

  @override
  void initState() {
    super.initState();
    if (_pickupMinute == 0) {
      _pickupHour = (_pickupHour + 1) % 24;
    }
    _loadCard();
  }

  // Load active payment card
  Future<void> _loadCard() async {
    setState(() => _cardLoaded = false);
    final card = await _paymentService.getActiveCard();
    if (mounted) {
      setState(() {
        _activeCard = card;
        _cardLoaded = true;
      });
    }
  }

  // Helper getters
  bool get _hasActiveCard => _activeCard != null && _activeCard!.isActive;

  bool get _isPickupTimeValid {
    final now = TimeOfDay.now();
    return (_pickupHour * 60 + _pickupMinute) >= (now.hour * 60 + now.minute);
  }

  // Format pickup time
  String get _pickupTimeStr =>
      '${_pickupHour.toString().padLeft(2, '0')}:${_pickupMinute.toString().padLeft(2, '0')}';

  Map<String, List<CartItem>> get _grouped {
    final Map<String, List<CartItem>> map = {};
    for (final item in widget.cart) {
      map.putIfAbsent(item.menuItem.shopId, () => []).add(item);
    }
    return map;
  }

  // Calculate grand total across all shops
  double get _grandTotal => widget.cart.fold(0.0, (s, c) => s + c.totalPrice);

  void _increase(int i) => setState(() => widget.cart[i].quantity++);
  void _decrease(int i) => setState(() {
    if (widget.cart[i].quantity > 1) {
      widget.cart[i].quantity--;
    } else {
      widget.cart.removeAt(i);
    }
  });
  // Navigate to payment details screen
  void _goToPaymentDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentDetailsScreen()),
    ).then((_) => _loadCard());
  }

  // Confirm orders and show summary dialog
  Future<void> _confirmAndPay() async {
    if (!_isPickupTimeValid) {
      _snack('Please select a future pickup time.', isError: true);
      return;
    }
    if (widget.cart.isEmpty || !_hasActiveCard) return;

    setState(() => _loading = true);

    try {
      final grouped = _grouped;
      final Map<String, List<BankAccount>> shopBankAccounts = {};
      for (final shopId in grouped.keys) {
        shopBankAccounts[shopId] = await _paymentService
            .getShopBankAccountsOnce(shopId);
      }
      setState(() => _loading = false);
      if (!mounted) return;
      _showConfirmDialog(grouped, shopBankAccounts);
    } catch (e) {
      setState(() => _loading = false);
      _snack('Error: $e', isError: true);
    }
  }

  // Show order summary and confirmation dialog
  void _showConfirmDialog(
    Map<String, List<CartItem>> grouped,
    Map<String, List<BankAccount>> shopBankAccounts,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Orders',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.pending.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.pending),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.pending,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment on hold until each shop confirms.',
                        style: TextStyle(
                          color: AppColors.pending,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.green),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.credit_card,
                      color: AppColors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_activeCard!.bankName} ${_activeCard!.maskedNumber}',
                        style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              ...grouped.entries.map((entry) {
                final shopId = entry.key;
                final items = entry.value;
                final shopName = items.first.menuItem.shopName;
                final shopTotal = items.fold(0.0, (s, c) => s + c.totalPrice);
                final accounts = shopBankAccounts[shopId] ?? [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront,
                            color: AppColors.green,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            shopName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...items.map(
                        (c) => Text(
                          '${c.quantity}x ${c.menuItem.name}',
                          style: const TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Rs. ${shopTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (accounts.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Transfer to:',
                          style: TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...accounts.map(
                          (a) => Text(
                            '${a.bankName} · ${a.accountHolder} · ${a.accountNumber}',
                            style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${grouped.length} order${grouped.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Total: Rs. ${_grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _placeOrders();
            },
            child: const Text(
              'Place Orders',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Place orders and handle payment flow
  Future<void> _placeOrders() async {
    setState(() => _loading = true);
    try {
      final grouped = _grouped;

      for (final entry in grouped.entries) {
        final shopId = entry.key;
        final items = entry.value;
        final shopName = items.first.menuItem.shopName;
        final shopTotal = items.fold(0.0, (s, c) => s + c.totalPrice);

        final orderItems = items
            .map(
              (c) => {
                'name': c.menuItem.name,
                'price': c.menuItem.price,
                'quantity': c.quantity,
              },
            )
            .toList();

        await _orderService.placeOrder(
          shopId: shopId,
          shopName: shopName,
          items: orderItems,
          totalPrice: shopTotal,
          pickupTime: _pickupTimeStr,
        );
      }

      if (!mounted) return;
      widget.cart.clear();

      Navigator.pop(context);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            grouped.length > 1
                ? '${grouped.length} orders placed successfully!'
                : 'Order placed! Payment is on hold.',
          ),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
      _snack('Error: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Check Order',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: widget.cart.isEmpty
          ? const Center(
              child: Text(
                'Cart is empty.',
                style: TextStyle(color: AppColors.textGrey),
              ),
            )
          : Column(
              children: [
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
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.1),
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
                                      size: 15,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      shopName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Rs. ${shopTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppColors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          ...shopItems.asMap().entries.map((e) {
                            final idx = widget.cart.indexOf(e.value);
                            final c = e.value;
                            return Container(
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
                                          c.menuItem.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'Rs. ${c.menuItem.price.toStringAsFixed(2)} x ${c.quantity}',
                                          style: const TextStyle(
                                            color: AppColors.textGrey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          'Rs. ${c.totalPrice.toStringAsFixed(2)}',
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
                                        onTap: () => _decrease(idx),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        child: Text(
                                          '${c.quantity}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      _QtyBtn(
                                        icon: Icons.add,
                                        onTap: () => _increase(idx),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                // Bottom panel
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_cardLoaded)
                        _InfoRow(
                          icon: Icons.hourglass_top,
                          text: 'Checking payment card...',
                          color: AppColors.textGrey,
                        )
                      else if (!_hasActiveCard)
                        GestureDetector(
                          onTap: _goToPaymentDetails,
                          child: _InfoRow(
                            icon: Icons.credit_card_off,
                            text: 'No active card. Tap to add.',
                            color: AppColors.error,
                            hasBorder: true,
                          ),
                        )
                      else
                        _InfoRow(
                          icon: Icons.credit_card,
                          text:
                              '${_activeCard!.bankName} ${_activeCard!.maskedNumber}',
                          color: AppColors.green,
                          hasBorder: true,
                        ),
                      const SizedBox(height: 12),

                      // Pickup time
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isPickupTimeValid
                                ? AppColors.border
                                : AppColors.error,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Pickup Time',
                                  style: TextStyle(
                                    color: AppColors.textGrey,
                                    fontSize: 12,
                                  ),
                                ),
                                if (!_isPickupTimeValid)
                                  const Text(
                                    'Select a future time',
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _TimeDropdown(
                                    label: 'Hour',
                                    // FIX: initialValue → value
                                    value: _pickupHour,
                                    items: List.generate(24, (i) => i),
                                    onChanged: (v) =>
                                        setState(() => _pickupHour = v!),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    ':',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: _TimeDropdown(
                                    label: 'Min',
                                    value: _pickupMinute,
                                    items: [
                                      0,
                                      5,
                                      10,
                                      15,
                                      20,
                                      25,
                                      30,
                                      35,
                                      40,
                                      45,
                                      50,
                                      55,
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _pickupMinute = v!),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _pickupTimeStr,
                                  style: TextStyle(
                                    color: _isPickupTimeValid
                                        ? AppColors.green
                                        : AppColors.error,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

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
                                  '${grouped.length} orders',
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
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasActiveCard
                                ? AppColors.green
                                : AppColors.border,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _loading
                              ? null
                              : _hasActiveCard
                              ? _confirmAndPay
                              : _goToPaymentDetails,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _hasActiveCard
                                      ? grouped.length > 1
                                            ? 'Place ${grouped.length} Orders'
                                            : 'Place Order'
                                      : 'Add Payment Card First',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// Time selection dropdown widget
class _TimeDropdown extends StatelessWidget {
  final String label;
  final int value;
  final List<int> items;
  final ValueChanged<int?> onChanged;
  const _TimeDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    initialValue: value,
    dropdownColor: AppColors.surface,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textGrey, fontSize: 11),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    ),
    items: items
        .map(
          (i) => DropdownMenuItem(
            value: i,
            child: Text(i.toString().padLeft(2, '0')),
          ),
        )
        .toList(),
    onChanged: onChanged,
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool hasBorder;
  const _InfoRow({
    required this.icon,
    required this.text,
    required this.color,
    this.hasBorder = false,
  });
  // Info row widget for displaying card status and messages
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: hasBorder ? Border.all(color: color) : null,
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: color, fontSize: 13)),
        ),
      ],
    ),
  );
}

// Time selection dropdown widget
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
