import 'package:cloud_firestore/cloud_firestore.dart';

// All food categories
const List<String> kFoodCategories = [
  'All',
  'Rice and Meals',
  'Noodles and Pasta',
  'Fast Food',
  'Light Meals',
  'Sri Lankan Short Eats',
  'Breakfast Items',
  'Healthy Options',
  'Desserts',
  'Bakery Items',
  'Coffee and Hot Drinks',
  'Cold Beverages',
  'Soft Drinks',
  'Fresh Juices and Smoothies',
  'Milk-Based Drinks',
  'Ice Cream',
  'Snacks and Packaged Foods',
];

class MenuItem {
  final String id;
  final String shopId;
  final String shopName;
  final String name;
  final String description;
  final double price;
  final bool isAvailable;
  final String category;
  final String imageUrl;

  MenuItem({
    required this.id,
    required this.shopId,
    this.shopName = '',
    required this.name,
    required this.description,
    required this.price,
    required this.isAvailable,
    required this.category,
    this.imageUrl = '',
  });

  factory MenuItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MenuItem(
      id: doc.id,
      shopId: d['shopId'] ?? '',
      shopName: d['shopName'] ?? '',
      name: d['name'] ?? '',
      description: d['description'] ?? '',
      price: (d['price'] ?? 0).toDouble(),
      isAvailable: d['isAvailable'] ?? true,
      category: d['category'] ?? 'Light Meals',
      imageUrl: d['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'shopId': shopId,
    'shopName': shopName,
    'name': name,
    'description': description,
    'price': price,
    'isAvailable': isAvailable,
    'category': category,
    'imageUrl': imageUrl,
  };
}
