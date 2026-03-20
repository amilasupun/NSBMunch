import 'package:flutter/material.dart';
import 'package:nsbmunch/core/constants/app_colors.dart';
import 'package:nsbmunch/core/services/order_service.dart';
import 'package:nsbmunch/models/scheduled_order_model.dart';

// Scheduled Orders screen for students to view and manage their upcoming scheduled orders
class ScheduledOrdersScreen extends StatelessWidget {
  const ScheduledOrdersScreen({super.key});
  // This screen is separate from Quick Orders to keep the UI clean and focused
  @override
  Widget build(BuildContext context) {
    final orderService = OrderService();

    return StreamBuilder<List<ScheduledOrder>>(
      stream: orderService.getMyScheduledOrders(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.green),
          );
        }

        final orders = snap.data ?? [];

        if (orders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule, size: 60, color: AppColors.textGrey),
                SizedBox(height: 12),
                Text(
                  'No scheduled orders.',
                  style: TextStyle(color: AppColors.textGrey),
                ),
                SizedBox(height: 4),
                Text(
                  'Add items to cart and tap "Add to Scheduled".',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (ctx, i) =>
              _ScheduledCard(order: orders[i], orderService: orderService),
        );
      },
    );
  }
}

// Individual scheduled order card widget with edit/delete functionality
class _ScheduledCard extends StatelessWidget {
  final ScheduledOrder order;
  final OrderService orderService;
  const _ScheduledCard({required this.order, required this.orderService});

  void _edit(BuildContext ctx) {
    final items = List<Map<String, dynamic>>.from(
      order.items.map((i) => Map<String, dynamic>.from(i)),
    );
    DateTime pickupDate = _parseDate(order.pickupDate);
    TimeOfDay pickupTime = _parseTime(order.pickupTime);
    TimeOfDay payTime = _parseTime(order.paymentTime);

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setS) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Edit Scheduled Order',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...List.generate(
                  items.length,
                  (i) => Row(
                    children: [
                      Expanded(
                        child: Text(
                          items[i]['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.remove,
                          color: AppColors.green,
                          size: 18,
                        ),
                        onPressed: () => setS(() {
                          if ((items[i]['quantity'] as int) > 1) {
                            items[i]['quantity'] =
                                (items[i]['quantity'] as int) - 1;
                          } else {
                            items.removeAt(i);
                          }
                        }),
                      ),
                      Text(
                        '${items[i]['quantity']}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add,
                          color: AppColors.green,
                          size: 18,
                        ),
                        onPressed: () => setS(() {
                          items[i]['quantity'] =
                              (items[i]['quantity'] as int) + 1;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _EditTile(
                  label: 'Date: ${_fmtDate(pickupDate)}',
                  icon: Icons.calendar_today,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: dCtx,
                      initialDate: pickupDate,
                      // Allow today
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                      builder: (c, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppColors.green,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (d != null) setS(() => pickupDate = d);
                  },
                ),
                const SizedBox(height: 8),
                _EditTile(
                  label: 'Pickup: ${_fmtTime(pickupTime)}',
                  icon: Icons.access_time,
                  onTap: () async {
                    final t = await showTimePicker(
                      context: dCtx,
                      initialTime: pickupTime,
                      builder: (c, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppColors.green,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (t != null) setS(() => pickupTime = t);
                  },
                ),
                const SizedBox(height: 8),
                _EditTile(
                  label: 'Auto Pay: ${_fmtTime(payTime)}',
                  icon: Icons.payment,
                  onTap: () async {
                    final t = await showTimePicker(
                      context: dCtx,
                      initialTime: payTime,
                      builder: (c, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppColors.green,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (t != null) setS(() => payTime = t);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
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
                final total = items.fold(
                  0.0,
                  (s, i) => s + (i['price'] as double) * (i['quantity'] as int),
                );
                await orderService.updateScheduledOrder(order.id, {
                  'items': items,
                  'totalPrice': total,
                  'pickupDate': _fmtDate(pickupDate),
                  'pickupTime': _fmtTime(pickupTime),
                  'paymentTime': _fmtTime(payTime),
                });
                if (dCtx.mounted) Navigator.pop(dCtx);
              },
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _delete(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Scheduled Order?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will delete the order and cancel the auto payment.',
          style: TextStyle(color: AppColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text(
              'Cancel',
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
              await orderService.deleteScheduledOrder(order.id);
              if (dCtx.mounted) Navigator.pop(dCtx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  DateTime _parseDate(String s) {
    try {
      final parts = s.split('/');
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } catch (_) {
      return DateTime.now().add(const Duration(days: 1));
    }
  }

  TimeOfDay _parseTime(String s) {
    try {
      final parts = s.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
  }

  static String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
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
      case 'hold':
        payColor = AppColors.pending;
        payLabel = 'Payment On Hold';
        break;
      default:
        payColor = AppColors.pending;
        payLabel = 'Payment Pending';
    }

    // Order status
    Color orderStatusColor;
    String orderStatusLabel;
    switch (order.orderStatus) {
      case 'confirmed':
        orderStatusColor = AppColors.green;
        orderStatusLabel = 'Order Confirmed';
        break;
      case 'cancelled':
        orderStatusColor = AppColors.error;
        orderStatusLabel = 'Order Cancelled';
        break;
      case 'ready':
        orderStatusColor = AppColors.green;
        orderStatusLabel = 'Order Ready';
        break;
      case 'completed':
        orderStatusColor = Colors.grey;
        orderStatusLabel = 'Order Picked Up';
        break;
      default:
        orderStatusColor = order.triggered
            ? AppColors.blue
            : AppColors.textGrey;
        orderStatusLabel = order.triggered ? 'Sent to Shop' : 'Scheduled';
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
              if (!order.triggered)
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 18,
                      ),
                      onPressed: () => _edit(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                        size: 18,
                      ),
                      onPressed: () => _delete(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
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
          const SizedBox(height: 6),

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

          // Date/time info
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 13,
                color: AppColors.textGrey,
              ),
              const SizedBox(width: 4),
              Text(
                '${order.pickupDate}  ${order.pickupTime}',
                style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.payment, size: 13, color: AppColors.textGrey),
              const SizedBox(width: 4),
              Text(
                'Auto Pay: ${order.paymentTime}',
                style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
              ),
            ],
          ),

          const Divider(color: AppColors.border, height: 14),

          // Total + status badges
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
                  _StatusBadge(
                    label: orderStatusLabel,
                    color: orderStatusColor,
                  ),
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

// Status badge widget used for displaying order and payment status with color coding
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

class _EditTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _EditTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  // Reusable tile widget for editing date/time in the scheduled order edit dialog
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.green, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    ),
  );
}
