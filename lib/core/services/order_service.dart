import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:nsbmunch/models/menu_item_model.dart';
import 'package:nsbmunch/models/order_model.dart';
import 'package:nsbmunch/models/scheduled_order_model.dart';

class OrderService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  // order number generator
  String _generateOrderNumber(String shopId) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final shopPart = shopId.length > 4
        ? shopId.substring(0, 4).toUpperCase()
        : shopId.toUpperCase();
    return 'ORD-$shopPart-$ts';
  }

  // image upload and delete
  Future<String> _uploadImage(File file, String shopId) async {
    final name = '${shopId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child('menu_images/$name');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> _deleteImage(String url) async {
    if (url.isEmpty) return;
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }

  // menu item CRUD operations
  Stream<List<MenuItem>> getMenuItems(String shopId) {
    return _db
        .collection('menu_items')
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map((s) => s.docs.map((d) => MenuItem.fromDoc(d)).toList());
  }

  Future<void> addMenuItem(MenuItem item, {File? imageFile}) async {
    String imageUrl = '';
    if (imageFile != null) {
      imageUrl = await _uploadImage(imageFile, item.shopId);
    }
    final map = item.toMap();
    map['imageUrl'] = imageUrl;
    await _db.collection('menu_items').add(map);
  }

  Future<void> updateMenuItem(MenuItem item, {File? newImageFile}) async {
    String imageUrl = item.imageUrl;
    if (newImageFile != null) {
      await _deleteImage(item.imageUrl);
      imageUrl = await _uploadImage(newImageFile, item.shopId);
    }
    final map = item.toMap();
    map['imageUrl'] = imageUrl;
    await _db.collection('menu_items').doc(item.id).update(map);
  }

  Future<void> deleteMenuItem(String itemId, String imageUrl) async {
    await _deleteImage(imageUrl);
    await _db.collection('menu_items').doc(itemId).delete();
  }

  // place order
  Future<void> placeOrder({
    required String shopId,
    required String shopName,
    required List<Map<String, dynamic>> items,
    required double totalPrice,
    required String pickupTime,
  }) async {
    final uid = _auth.currentUser?.uid ?? '';
    final orderNumber = _generateOrderNumber(shopId);

    await _db.collection('orders').add({
      'userId': uid,
      'shopId': shopId,
      'shopName': shopName,
      'items': items,
      'totalPrice': totalPrice,
      'status': 'pending',
      'paymentStatus': 'hold',
      'pickupTime': pickupTime,
      'orderNumber': orderNumber,
      'isScheduled': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // confirm order  shop  setp 1 and step 2
  Future<void> confirmOrder(FoodOrder order) async {
    await _db.collection('orders').doc(order.id).update({
      'status': 'preparing',
      'paymentStatus': 'confirmed',
    });

    if (order.isScheduled) {
      await _updateScheduledOrderStatus(
        order.orderNumber,
        orderStatus: 'confirmed',
        paymentStatus: 'confirmed',
      );
    }
  }

  // cancel order
  Future<void> cancelOrder(FoodOrder order) async {
    await _db.collection('orders').doc(order.id).update({
      'status': 'cancelled',
      'paymentStatus': 'declined',
    });

    if (order.isScheduled) {
      await _updateScheduledOrderStatus(
        order.orderNumber,
        orderStatus: 'cancelled',
        paymentStatus: 'declined',
      );
    }
  }

  // make order ready  shop step 2
  Future<void> markOrderReady(FoodOrder order) async {
    await _db.collection('orders').doc(order.id).update({'status': 'ready'});

    if (order.isScheduled) {
      await _updateScheduledOrderStatus(
        order.orderNumber,
        orderStatus: 'ready',
      );
    }
  }

  // pickup order  shop step 3
  Future<void> markOrderPickedUp(FoodOrder order) async {
    await _db.collection('orders').doc(order.id).update({
      'status': 'completed',
    });

    if (order.isScheduled) {
      await _updateScheduledOrderStatus(
        order.orderNumber,
        orderStatus: 'completed',
      );
    }
  }

  // update scheduled order status by order number
  Future<void> _updateScheduledOrderStatus(
    String orderNumber, {
    String? orderStatus,
    String? paymentStatus,
  }) async {
    if (orderNumber.isEmpty) return;
    final snap = await _db
        .collection('scheduled_orders')
        .where('orderNumber', isEqualTo: orderNumber)
        .get();
    for (final doc in snap.docs) {
      final update = <String, dynamic>{};
      if (orderStatus != null) update['orderStatus'] = orderStatus;
      if (paymentStatus != null) update['paymentStatus'] = paymentStatus;
      if (update.isNotEmpty) await doc.reference.update(update);
    }
  }

  // get orders
  Stream<List<FoodOrder>> getMyOrders() {
    final uid = _auth.currentUser?.uid ?? '';
    return _db
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => FoodOrder.fromDoc(d)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<FoodOrder>> getShopOrders(String shopId) {
    return _db
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => FoodOrder.fromDoc(d)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // scheduled orders
  Future<void> placeScheduledOrder(ScheduledOrder order) async {
    await _db.collection('scheduled_orders').add(order.toMap());
  }

  Stream<List<ScheduledOrder>> getMyScheduledOrders() {
    final uid = _auth.currentUser?.uid ?? '';
    return _db
        .collection('scheduled_orders')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => ScheduledOrder.fromDoc(d)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Future<void> updateScheduledOrder(
    String id,
    Map<String, dynamic> data,
  ) async {
    await _db.collection('scheduled_orders').doc(id).update(data);
  }

  Future<void> deleteScheduledOrder(String id) async {
    await _db.collection('scheduled_orders').doc(id).delete();
  }
}
