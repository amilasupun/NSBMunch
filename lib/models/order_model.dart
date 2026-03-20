import 'package:cloud_firestore/cloud_firestore.dart';

class FoodOrder {
  final String id;
  final String userId;
  final String shopId;
  final String shopName;
  final List<Map<String, dynamic>> items;
  final double totalPrice;
  final String status;
  final String paymentStatus;
  final String pickupTime;
  final String orderNumber;
  final bool isScheduled;
  final DateTime createdAt;

  FoodOrder({
    required this.id,
    required this.userId,
    required this.shopId,
    required this.shopName,
    required this.items,
    required this.totalPrice,
    required this.status,
    required this.paymentStatus,
    required this.pickupTime,
    this.orderNumber = '',
    this.isScheduled = false,
    required this.createdAt,
  });

  factory FoodOrder.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FoodOrder(
      id: doc.id,
      userId: d['userId'] ?? '',
      shopId: d['shopId'] ?? '',
      shopName: d['shopName'] ?? '',
      items: List<Map<String, dynamic>>.from(d['items'] ?? []),
      totalPrice: (d['totalPrice'] ?? 0).toDouble(),
      status: d['status'] ?? 'pending',
      paymentStatus: d['paymentStatus'] ?? 'hold',
      pickupTime: d['pickupTime'] ?? '',
      orderNumber: d['orderNumber'] ?? '',
      isScheduled: d['isScheduled'] ?? false,
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
