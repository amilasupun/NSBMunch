import 'package:flutter/material.dart';
import 'package:nsbmunch/core/constants/app_colors.dart';
import 'package:nsbmunch/core/services/order_service.dart';
import 'package:nsbmunch/models/order_model.dart';
import 'package:intl/intl.dart';

// Quick Orders tab for students to view their recent non-scheduled orders
class QuickOrdersScreen extends StatelessWidget {
  const QuickOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderService = OrderService();

    return StreamBuilder<List<FoodOrder>>(
      stream: orderService.getMyOrders(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.green),
          );
        }
        final orders = (snap.data ?? []).where((o) => !o.isScheduled).toList();

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
                  'No quick orders yet.',
                  style: TextStyle(color: AppColors.textGrey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (ctx, i) => _OrderCard(order: orders[i]),
        );
      },
    );
  }
}

// Individual order card widget
class _OrderCard extends StatelessWidget {
  final FoodOrder order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy').format(order.createdAt);
    final timeStr = DateFormat('hh:mm a').format(order.createdAt);

    // Payment status
    Color payColor;
    String payLabel;
    switch (order.paymentStatus) {
      case 'confirmed':
        payColor = AppColors.green;
        payLabel = 'Payment Successful';
        break;
      case 'declined':
        payColor = AppColors.error;
        payLabel = 'Payment Declined';
        break;
      default:
        payColor = AppColors.pending;
        payLabel = 'Payment On Hold';
    }

    // Order status
    Color statusColor;
    String statusLabel;
    switch (order.status) {
      case 'preparing':
        statusColor = AppColors.pending;
        statusLabel = 'Preparing';
        break;
      case 'ready':
        statusColor = AppColors.green;
        statusLabel = 'Order Ready';
        break;
      case 'completed':
        statusColor = Colors.grey;
        statusLabel = 'Order Picked Up';
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        statusLabel = 'Cancelled';
        break;
      default:
        statusColor = AppColors.blue;
        statusLabel = 'Pending';
    }

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
          // Shop + date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.shopName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                '$dateStr  $timeStr',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
            ],
          ),

          if (order.orderNumber.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              order.orderNumber,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
          const SizedBox(height: 8),

          // Pickup time
          if (order.pickupTime.isNotEmpty)
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

          const Divider(color: AppColors.border, height: 14),

          // Total + badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rs. ${order.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(label: statusLabel, color: statusColor),
                  const SizedBox(height: 4),
                  _StatusBadge(label: payLabel, color: payColor),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
    ),
  );
}
