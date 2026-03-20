import 'package:flutter/material.dart';
import 'package:nsbmunch/core/constants/app_colors.dart';
import 'package:nsbmunch/core/constants/app_strings.dart';
import 'package:nsbmunch/core/services/auth_service.dart';
import 'package:nsbmunch/models/cart_item_model.dart';
import 'package:nsbmunch/screens/auth/login_screen.dart';
import 'package:nsbmunch/screens/shared/browse_food_screen.dart';
import 'package:nsbmunch/screens/student/cart_screen.dart';
import 'package:nsbmunch/screens/student/quick_orders_screen.dart';
import 'package:nsbmunch/screens/student/scheduled_orders_screen.dart';
import 'package:nsbmunch/screens/student/payment_details_screen.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  int _tab = 0;
  final List<CartItem> _cart = [];

  int get _cartCount => _cart.fold(0, (sum, c) => sum + c.quantity);

  Future<void> _logout() async {
    await AuthService().logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _openCart() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart is empty. Add items first.'),
          backgroundColor: AppColors.textGrey,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CartScreen(cart: _cart)),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          AppStrings.appName,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_tab == 0)
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.shopping_cart_outlined,
                    color: Colors.white,
                  ),
                  onPressed: _openCart,
                ),
                if (_cartCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _cartCount > 9 ? '9+' : '$_cartCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.green,
        unselectedItemColor: AppColors.textGrey,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Food',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flash_on),
            label: 'Quick Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Scheduled',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.credit_card),
            label: 'Payment',
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          BrowseFoodScreen(cart: _cart, onCartUpdate: () => setState(() {})),
          const QuickOrdersScreen(),
          const ScheduledOrdersScreen(),
          const PaymentDetailsScreen(),
        ],
      ),
    );
  }
}
