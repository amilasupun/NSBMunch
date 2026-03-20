import 'package:flutter/material.dart';
import 'package:nsbmunch/core/constants/app_colors.dart';
import 'package:nsbmunch/core/constants/app_strings.dart';
import 'package:nsbmunch/core/services/auth_service.dart';
import 'package:nsbmunch/screens/auth/login_screen.dart';
import 'package:nsbmunch/screens/vendor/incoming_orders_screen.dart';
import 'package:nsbmunch/screens/vendor/manage_menu_screen.dart';
import 'package:nsbmunch/screens/vendor/bank_account_screen.dart';
import 'package:nsbmunch/screens/vendor/sales_screen.dart';

class VendorHome extends StatefulWidget {
  const VendorHome({super.key});

  @override
  State<VendorHome> createState() => _VendorHomeState();
}

class _VendorHomeState extends State<VendorHome> {
  int _tab = 0;

  Future<void> _logout() async {
    await AuthService().logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
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
          // Logout button
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
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Menu',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: 'Bank',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Sales'),
        ],
      ),

      body: IndexedStack(
        index: _tab,
        children: const [
          IncomingOrdersScreen(),
          ManageMenuScreen(),
          BankAccountScreen(),
          SalesScreen(),
        ],
      ),
    );
  }
}
