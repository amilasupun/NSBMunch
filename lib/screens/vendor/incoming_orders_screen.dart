import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nsbmunch/core/constants/app_colors.dart';
import 'package:nsbmunch/core/services/order_service.dart';
import 'package:nsbmunch/core/services/payment_service.dart';
import 'package:nsbmunch/models/order_model.dart';
import 'package:nsbmunch/models/bank_account_model.dart';
import 'package:nsbmunch/screens/vendor/bank_account_screen.dart';
import 'package:intl/intl.dart';

// Vendor screen to view incoming orders and manage order status
class IncomingOrdersScreen extends StatelessWidget {
  const IncomingOrdersScreen({super.key});

  Future<String?> _getShopId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.data()?['shopId'] as String?;
  }

  // Helper to get color based on order status
  Color _statusColor(String status) {
    switch (status) {
      case 'preparing':
        return AppColors.pending;
      case 'ready':
        return AppColors.green;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.blue;
    }
  }

  // Main build method
  @override
  Widget build(BuildContext context) {
    final orderService = OrderService();

    return FutureBuilder<String?>(
      future: _getShopId(),
      builder: (context, shopSnap) {
        if (shopSnap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.green),
          );
        }
        final shopId = shopSnap.data;
        if (shopId == null || shopId.isEmpty) {
          return const Center(
            child: Text(
              'Shop not found.',
              style: TextStyle(color: AppColors.textGrey),
            ),
          );
        }
        // Stream of orders for this shop
        return StreamBuilder<List<FoodOrder>>(
          stream: orderService.getShopOrders(shopId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.green),
              );
            }
            // List of orders
            final orders = snap.data ?? [];
            if (orders.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 60,
                      color: AppColors.textGrey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No orders yet.',
                      style: TextStyle(color: AppColors.textGrey),
                    ),
                  ],
                ),
              );
            }
            // Show list of orders
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (ctx, i) {
                final order = orders[i];
                return _OrderCard(
                  order: order,
                  orderService: orderService,
                  shopId: shopId,
                  statusColor: _statusColor(order.status),
                );
              },
            );
          },
        );
      },
    );
  }
}

// order card widget with status badges and action buttons based on order status
class _OrderCard extends StatelessWidget {
  final FoodOrder order;
  final OrderService orderService;
  final String shopId;
  final Color statusColor;

  const _OrderCard({
    required this.order,
    required this.orderService,
    required this.shopId,
    required this.statusColor,
  });

  // Handle confirm action with bank account check
  Future<void> _handleConfirm(BuildContext context) async {
    final paymentService = PaymentService();
    final accounts = await paymentService.getShopBankAccountsOnce(shopId);

    if (!context.mounted) return;

    if (accounts.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Bank Account Required',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'You must add at least one bank account before confirming orders.\n\nStudents need bank details to make payment.',
            style: TextStyle(color: AppColors.textGrey, height: 1.5),
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
              onPressed: () {
                Navigator.pop(ctx);
                // Go to bank account screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BankAccountScreen()),
                );
              },
              child: const Text(
                'Add Bank Account',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    // Has bank accounts
    if (!context.mounted) return;
    _showConfirmDialog(context, accounts);
  }

  void _showConfirmDialog(BuildContext context, List<BankAccount> accounts) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Confirm Order?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm order ${order.orderNumber}?',
              style: const TextStyle(color: AppColors.textGrey),
            ),
            const SizedBox(height: 12),
            // Show bank accounts
            const Text(
              'Payment to:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ...accounts.map(
              (a) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.bankName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${a.accountHolder} — ${a.accountNumber}',
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
              await orderService.confirmOrder(order);
            },
            child: const Text(
              'Confirm',
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

  // Show cancel confirmation dialog
  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Cancel Order?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Cancel order ${order.orderNumber}?\nUser will be notified.',
          style: const TextStyle(color: AppColors.textGrey, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Back',
              style: TextStyle(color: AppColors.textGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await orderService.cancelOrder(order);
            },
            child: const Text(
              'Cancel Order',
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

  // Build method for order card with status badges and action buttons based on order status
  @override
  Widget build(BuildContext context) {
    final isPaid = order.paymentStatus == 'confirmed';
    final isHold = order.paymentStatus == 'hold';
    final dateStr = DateFormat('dd MMM  hh:mm a').format(order.createdAt);

    final Color payColor = isHold
        ? AppColors.pending
        : isPaid
        ? AppColors.green
        : AppColors.error;
    final String payLabel = isHold
        ? 'Payment Hold'
        : isPaid
        ? 'Payment Confirmed'
        : 'Payment Declined';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order number + badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber.isNotEmpty
                          ? order.orderNumber
                          : 'Order #${order.id.substring(0, 6).toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (order.isScheduled)
                      const Text(
                        'Scheduled Order',
                        style: TextStyle(
                          color: AppColors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Badge(label: order.status.toUpperCase(), color: statusColor),
                  const SizedBox(height: 4),
                  _Badge(label: payLabel, color: payColor),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),

          Text(
            dateStr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),

          // Items
          ...order.items.map(
            (item) => Text(
              '${item['quantity']}x  ${item['name']}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ),

          if (order.pickupTime.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 13,
                  color: AppColors.textGrey,
                ),
                const SizedBox(width: 4),
                Text(
                  'Pickup: ${order.pickupTime}',
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],

          const Divider(color: AppColors.border, height: 14),

          Text(
            'Total: Rs. ${order.totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          // Action buttons based on order status
          if (order.status == 'pending')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showCancelDialog(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleConfirm(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),

          // Step buttons for preparing, ready, picked up
          if (order.status == 'preparing')
            _StepBtn(
              stepLabel: 'Step 1',
              label: 'Order Ready',
              color: AppColors.green,
              onTap: () async => await orderService.markOrderReady(order),
            ),

          // Only show  if order is ready
          if (order.status == 'ready')
            _StepBtn(
              stepLabel: 'Step 2',
              label: 'Order Picked Up',
              color: Colors.grey,
              onTap: () async => await orderService.markOrderPickedUp(order),
            ),
        ],
      ),
    );
  }
}

// step button widget for order status updates
class _StepBtn extends StatelessWidget {
  final String stepLabel;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _StepBtn({
    required this.stepLabel,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              stepLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

// badge
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
    ),
  );
}
