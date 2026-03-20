import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nsbmunch/core/constants/app_colors.dart';
import 'package:nsbmunch/core/services/order_service.dart';
import 'package:nsbmunch/models/menu_item_model.dart';
import 'package:nsbmunch/widgets/app_widgets.dart';

class ManageMenuScreen extends StatefulWidget {
  const ManageMenuScreen({super.key});

  @override
  State<ManageMenuScreen> createState() => _ManageMenuScreenState();
}

class _ManageMenuScreenState extends State<ManageMenuScreen> {
  final _orderService = OrderService();
  final _db = FirebaseFirestore.instance;
  String _filterCat = 'All';

  String _shopId = '';
  String _shopName = 'My Shop';
  bool _shopLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadShopInfo();
  }

  Future<void> _loadShopInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    if (mounted) {
      setState(() {
        _shopId = data['shopId'] ?? '';
        _shopName = data['shopName'] ?? 'My Shop';
        _shopLoaded = true;
      });
    }
  }

  void _showItemDialog({MenuItem? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.price.toString() : '',
    );
    String selectedCat = existing?.category ?? kFoodCategories[1];
    File? pickedImage;
    bool loading = false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            existing == null ? 'Add Menu Item' : 'Edit Menu Item',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading) ...[
                    const LinearProgressIndicator(
                      color: AppColors.green,
                      backgroundColor: AppColors.border,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Saving... please wait',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Image picker
                  GestureDetector(
                    onTap: loading
                        ? null
                        : () async {
                            final picked = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 75,
                            );
                            if (picked != null) {
                              setS(() => pickedImage = File(picked.path));
                            }
                          },
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: pickedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                pickedImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : existing != null && existing.imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                existing.imageUrl,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  color: Colors.white.withValues(alpha: 0.4),
                                  size: 32,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tap to add photo (PNG/JPG)',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedCat,
                    dropdownColor: AppColors.surface,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    items: kFoodCategories
                        .where((c) => c != 'All')
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: loading
                        ? null
                        : (val) => setS(() => selectedCat = val!),
                  ),
                  const SizedBox(height: 12),

                  AppTextField(
                    label: 'Item Name',
                    hint: 'e.g. Rice & Curry',
                    controller: nameCtrl,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter item name' : null,
                  ),
                  const SizedBox(height: 12),

                  AppTextField(
                    label: 'Description',
                    hint: 'e.g. With 3 curries',
                    controller: descCtrl,
                  ),
                  const SizedBox(height: 12),

                  AppTextField(
                    label: 'Price (Rs.)',
                    hint: '0.00',
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter price';
                      if (double.tryParse(v) == null) {
                        return 'Enter valid number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
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
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setS(() => loading = true);
                      try {
                        final item = MenuItem(
                          id: existing?.id ?? '',
                          shopId: _shopId,
                          shopName: _shopName,
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          price: double.parse(priceCtrl.text),
                          isAvailable: existing?.isAvailable ?? true,
                          category: selectedCat,
                          imageUrl: existing?.imageUrl ?? '',
                        );
                        if (existing == null) {
                          await _orderService.addMenuItem(
                            item,
                            imageFile: pickedImage,
                          );
                        } else {
                          await _orderService.updateMenuItem(
                            item,
                            newImageFile: pickedImage,
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setS(() => loading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
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

  void _confirmDelete(MenuItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Item?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Delete "${item.name}"?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
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
              await _orderService.deleteMenuItem(item.id, item.imageUrl);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_shopLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.green),
      );
    }

    if (_shopId.isEmpty) {
      return const Center(
        child: Text(
          'Shop not found.',
          style: TextStyle(color: AppColors.textGrey),
        ),
      );
    }

    return StreamBuilder<List<MenuItem>>(
      stream: _orderService.getMenuItems(_shopId),
      builder: (context, menuSnap) {
        if (menuSnap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.green),
          );
        }

        final allItems = menuSnap.data ?? [];
        final items = _filterCat == 'All'
            ? allItems
            : allItems.where((i) => i.category == _filterCat).toList();

        return Column(
          children: [
            // Add item button
            Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Add New Item',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => _showItemDialog(),
                ),
              ),
            ),

            // Category chips
            Container(
              color: Colors.black,
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: kFoodCategories.length,
                itemBuilder: (ctx, i) {
                  final cat = kFoodCategories[i];
                  final selected = cat == _filterCat;
                  return GestureDetector(
                    onTap: () => setState(() => _filterCat = cat),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.green
                            : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? AppColors.green : AppColors.border,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: selected ? Colors.white : AppColors.textGrey,
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Item count
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${items.length} item${items.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ),
            ),

            // Menu list
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'No items in this category.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: item.imageUrl.isNotEmpty
                                    ? Image.network(
                                        item.imageUrl,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 56,
                                        height: 56,
                                        color: AppColors.green.withValues(
                                          alpha: 0.12,
                                        ),
                                        child: const Icon(
                                          Icons.fastfood,
                                          color: AppColors.green,
                                          size: 28,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      item.category,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Rs. ${item.price.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                                onPressed: () =>
                                    _showItemDialog(existing: item),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.error,
                                ),
                                onPressed: () => _confirmDelete(item),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
