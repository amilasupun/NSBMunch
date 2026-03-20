import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nsbmunch/core/constants/app_colors.dart';
import 'package:intl/intl.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  String? _shopId;
  bool _shopLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadShopId();
  }

  Future<void> _loadShopId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (mounted) {
      setState(() {
        _shopId = doc.data()?['shopId'] ?? '';
        _shopLoaded = true;
      });
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    if (!_shopLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.green),
      );
    }

    if (_shopId == null || _shopId!.isEmpty) {
      return const Center(
        child: Text(
          'Shop not found.',
          style: TextStyle(color: AppColors.textGrey),
        ),
      );
    }

    // Real time stream of today's orders
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('shopId', isEqualTo: _shopId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.green),
          );
        }

        final allOrders = snap.data?.docs ?? [];

        // Filter today's orders only
        final todayOrders = allOrders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final createdAt = data['createdAt'];
          if (createdAt == null) return false;
          final date = (createdAt as Timestamp).toDate();
          return _isToday(date);
        }).toList();

        // Stats
        double totalIncome = 0;
        int completedCount = 0;
        int pendingCount = 0;
        int cancelledCount = 0;
        final Map<String, int> itemCounts = {};

        for (final doc in todayOrders) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? '';
          final total = (data['totalPrice'] ?? 0).toDouble();

          if (status == 'completed' || status == 'ready') {
            totalIncome += total;
            completedCount++;

            // Count best selling items from completed/ready orders
            final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
            for (final item in items) {
              final name = item['name'] as String? ?? '';
              final qty = (item['quantity'] as int?) ?? 1;
              itemCounts[name] = (itemCounts[name] ?? 0) + qty;
            }
          } else if (status == 'cancelled') {
            cancelledCount++;
          } else {
            pendingCount++;
          }
        }

        // Sort best sellers
        final bestSellers = itemCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top5 = bestSellers.take(5).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Sales",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(DateTime.now()),
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Total income card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.green),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Income',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rs. ${totalIncome.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'From $completedCount completed order${completedCount != 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats row — Completed / Pending / Cancelled
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Completed',
                    count: completedCount,
                    color: AppColors.green,
                    icon: Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'Pending',
                    count: pendingCount,
                    color: AppColors.pending,
                    icon: Icons.hourglass_top,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'Cancelled',
                    count: cancelledCount,
                    color: AppColors.error,
                    icon: Icons.cancel_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Best selling foods
            if (top5.isNotEmpty) ...[
              const Text(
                'Best Selling Today',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: top5.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final item = entry.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: entry.key < top5.length - 1
                            ? const Border(
                                bottom: BorderSide(color: AppColors.border),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: rank == 1
                                  ? AppColors.green
                                  : AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: rank == 1
                                    ? AppColors.green
                                    : AppColors.border,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$rank',
                                style: TextStyle(
                                  color: rank == 1
                                      ? Colors.white
                                      : AppColors.textGrey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.key,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            '${item.value} sold',
                            style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Today's orders list
            const Text(
              "Today's Orders",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            if (todayOrders.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No orders today.',
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                ),
              )
            else
              ...todayOrders.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final orderNumber = data['orderNumber'] as String? ?? doc.id;
                final total = (data['totalPrice'] ?? 0).toDouble();
                final status = data['status'] as String? ?? '';
                final createdAt =
                    (data['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now();
                final timeStr = DateFormat('hh:mm a').format(createdAt);

                Color statusColor;
                String statusLabel;
                switch (status) {
                  case 'completed':
                    statusColor = AppColors.green;
                    statusLabel = 'Completed';
                    break;
                  case 'ready':
                    statusColor = AppColors.green;
                    statusLabel = 'Ready';
                    break;
                  case 'cancelled':
                    statusColor = AppColors.error;
                    statusLabel = 'Cancelled';
                    break;
                  case 'preparing':
                    statusColor = AppColors.pending;
                    statusLabel = 'Preparing';
                    break;
                  default:
                    statusColor = AppColors.textGrey;
                    statusLabel = 'Pending';
                }

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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              orderNumber,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Rs. ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.textGrey, fontSize: 11),
        ),
      ],
    ),
  );
}
