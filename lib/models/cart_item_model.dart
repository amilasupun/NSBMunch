import 'package:nsbmunch/models/menu_item_model.dart';

class CartItem {
  final MenuItem menuItem;
  int quantity;

  CartItem({required this.menuItem, this.quantity = 1});
  double get totalPrice => menuItem.price * quantity;
}
