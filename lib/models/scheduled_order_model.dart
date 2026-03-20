import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduledOrder {
  final String id;
  final String userId;
  final String shopId;
  final String shopName;
  final List<Map<String, dynamic>> items;
  final double totalPrice;
  final String pickupDate;
  final String pickupTime;
  final String paymentTime;
  final String paymentStatus;
  final String orderStatus;
  final String orderNumber;
  final bool triggered;
  final DateTime createdAt;

  ScheduledOrder({
    required this.id,
    required this.userId,
    required this.shopId,
    required this.shopName,
    required this.items,
    required this.totalPrice,
    required this.pickupDate,
    required this.pickupTime,
    required this.paymentTime,
    required this.paymentStatus,
    this.orderStatus = '',
    this.orderNumber = '',
    this.triggered = false,
    required this.createdAt,
  });

  factory ScheduledOrder.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ScheduledOrder(
      id: doc.id,
      userId: d['userId'] ?? '',
      shopId: d['shopId'] ?? '',
      shopName: d['shopName'] ?? '',
      items: List<Map<String, dynamic>>.from(d['items'] ?? []),
      totalPrice: (d['totalPrice'] ?? 0).toDouble(),
      pickupDate: d['pickupDate'] ?? '',
      pickupTime: d['pickupTime'] ?? '',
      paymentTime: d['paymentTime'] ?? '',
      paymentStatus: d['paymentStatus'] ?? 'payment_pending',
      orderStatus: d['orderStatus'] ?? '',
      orderNumber: d['orderNumber'] ?? '',
      triggered: d['triggered'] ?? false,
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'shopId': shopId,
    'shopName': shopName,
    'items': items,
    'totalPrice': totalPrice,
    'pickupDate': pickupDate,
    'pickupTime': pickupTime,
    'paymentTime': paymentTime,
    'paymentStatus': paymentStatus,
    'orderStatus': orderStatus,
    'orderNumber': orderNumber,
    'triggered': triggered,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
