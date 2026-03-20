import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/auth_service.dart';
import '../auth/login_screen.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Admin Panel',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),

      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              color: const Color(0xFF2A2A2A),
              child: const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                indicatorColor: AppColors.green,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: 'Pending'),
                  Tab(text: 'Approved'),
                  Tab(text: 'Rejected'),
                ],
              ),
            ),

            // Tab views
            const Expanded(
              child: TabBarView(
                children: [
                  _ShopList(status: 'pending'),
                  _ShopList(status: 'active'),
                  _ShopList(status: 'rejected'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// shop list for each tab
class _ShopList extends StatelessWidget {
  final String status;
  const _ShopList({required this.status});

  // Update shop status in Firestore
  Future<void> _updateStatus(String uid, String newStatus) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'status': newStatus,
    });
  }

  // Confirm dialog
  Future<bool> _confirm(
    BuildContext context,
    String title,
    String msg,
    Color btnColor,
    String btnLabel,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(msg, style: const TextStyle(color: AppColors.textGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: btnColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(btnLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Listen to Firestore in real time
    final stream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: AppStrings.vendor)
        .where('status', isEqualTo: status)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.green),
          );
        }

        // Error massage
        if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong.'));
        }

        final docs = snapshot.data?.docs ?? [];

        // Empty state
        if (docs.isEmpty) {
          final msg = {
            'pending': 'No pending shop requests',
            'active': 'No approved shops yet',
            'rejected': 'No rejected shops',
          };
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.store_outlined,
                  size: 56,
                  color: AppColors.textGrey.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  msg[status] ?? 'No shops',
                  style: const TextStyle(color: AppColors.textGrey),
                ),
              ],
            ),
          );
        }

        // Shop cards
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final uid = docs[index].id;
            final shopName = data['shopName'] as String? ?? 'Unknown Shop';
            final owner = data['name'] as String? ?? 'Unknown';
            final email = data['email'] as String? ?? '-';
            final shopId = data['shopId'] as String? ?? '-';

            return _ShopCard(
              shopName: shopName,
              owner: owner,
              email: email,
              shopId: shopId,
              status: status,

              onApprove: () async {
                final ok = await _confirm(
                  context,
                  'Approve Shop',
                  'Approve "$shopName"? They can login immediately.',
                  AppColors.success,
                  'Approve',
                );
                if (ok) {
                  await _updateStatus(uid, 'active');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$shopName approved.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              },

              onReject: () async {
                final ok = await _confirm(
                  context,
                  'Reject Shop',
                  'Reject "$shopName"?',
                  AppColors.error,
                  'Reject',
                );
                if (ok) {
                  await _updateStatus(uid, 'rejected');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$shopName rejected.'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
            );
          },
        );
      },
    );
  }
}

// Shop card widget
class _ShopCard extends StatelessWidget {
  final String shopName;
  final String owner;
  final String email;
  final String shopId;
  final String status;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ShopCard({
    required this.shopName,
    required this.owner,
    required this.email,
    required this.shopId,
    required this.status,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    // Status badge
    Color badgeColor;
    String badgeLabel;
    switch (status) {
      case 'active':
        badgeColor = AppColors.success;
        badgeLabel = 'APPROVED';
        break;
      case 'rejected':
        badgeColor = AppColors.error;
        badgeLabel = 'REJECTED';
        break;
      default:
        badgeColor = AppColors.pending;
        badgeLabel = 'PENDING';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.green.withValues(alpha: 0.1),
                child: Text(
                  shopName[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shopName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      owner,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Email & Shop ID
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      size: 14,
                      color: AppColors.textGrey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.badge_outlined,
                      size: 14,
                      color: AppColors.textGrey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ID: $shopId',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons based on status
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Reject',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Approve',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // rejected to Approve
          if (status == 'rejected') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onApprove,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Approve This Shop',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],

          // approved to Reject
          if (status == 'active') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onReject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Reject Approval',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
