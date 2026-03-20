import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nsbmunch/core/constants/app_colors.dart';
import 'package:nsbmunch/core/services/payment_service.dart';
import 'package:nsbmunch/models/bank_account_model.dart';

// Bank Account screen for vendors to manage their bank account details
class BankAccountScreen extends StatefulWidget {
  const BankAccountScreen({super.key});

  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  final _paymentService = PaymentService();
  String _shopId = '';
  bool _loadingShop = true;

  @override
  void initState() {
    super.initState();
    _loadShopId();
  }

  // Load shop ID for current vendor
  Future<void> _loadShopId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (mounted) {
      setState(() {
        _shopId = doc.data()?['shopId'] ?? '';
        _loadingShop = false;
      });
    }
  }

  // Show add/edit bank account dialog
  void _showDialog({BankAccount? existing}) {
    final holderCtrl = TextEditingController(
      text: existing?.accountHolder ?? '',
    );
    final numberCtrl = TextEditingController(
      text: existing?.accountNumber ?? '',
    );
    final bankCtrl = TextEditingController(text: existing?.bankName ?? '');
    final branchCtrl = TextEditingController(text: existing?.branch ?? '');
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
            existing == null ? 'Add Bank Account' : 'Edit Bank Account',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Field(
                    ctrl: bankCtrl,
                    label: 'Bank Name',
                    hint: 'e.g. Bank of Ceylon',
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    ctrl: holderCtrl,
                    label: 'Account Holder',
                    hint: 'Full name as on bank',
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    ctrl: numberCtrl,
                    label: 'Account Number',
                    hint: '1234567890',
                    keyboard: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    ctrl: branchCtrl,
                    label: 'Branch',
                    hint: 'e.g. Homagama',
                  ),
                  if (loading) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(
                      color: AppColors.green,
                      backgroundColor: AppColors.border,
                    ),
                  ],
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
              // Save button handler
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setS(() => loading = true);
                      try {
                        final account = BankAccount(
                          id: existing?.id ?? '',
                          shopId: _shopId,
                          accountHolder: holderCtrl.text.trim(),
                          accountNumber: numberCtrl.text.trim(),
                          bankName: bankCtrl.text.trim(),
                          branch: branchCtrl.text.trim(),
                        );
                        if (existing == null) {
                          await _paymentService.addBankAccount(account);
                        } else {
                          await _paymentService.updateBankAccount(account);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setS(() => loading = false);
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

  // Delete confirmation dialog
  void _delete(BankAccount account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Account?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Delete ${account.bankName} — ${account.accountNumber}?',
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
              await _paymentService.deleteBankAccount(account.id);
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
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: canPop
          ? AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text(
                'Bank Account',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: _loadingShop
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.green),
            )
          : _shopId.isEmpty
          ? const Center(
              child: Text(
                'Shop not found.',
                style: TextStyle(color: AppColors.textGrey),
              ),
            )
          : StreamBuilder<List<BankAccount>>(
              stream: _paymentService.getShopBankAccounts(_shopId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.green),
                  );
                }
                final accounts = snap.data ?? [];
                // Max 1 bank account
                final hasAccount = accounts.isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info text
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.green.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: AppColors.green,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                hasAccount
                                    ? 'Your bank account is set. Students will transfer payment here.'
                                    : 'Add your bank account. Students will transfer payment here.',
                                style: const TextStyle(
                                  color: AppColors.green,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Show account card OR add button
                      if (hasAccount) ...[
                        // Account card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.green.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Bank name row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.green.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.account_balance,
                                          color: AppColors.green,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        accounts[0].bankName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Edit button only
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _showDialog(existing: accounts[0]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _InfoRow(
                                icon: Icons.person_outline,
                                label: 'Account Holder',
                                value: accounts[0].accountHolder,
                              ),
                              const SizedBox(height: 8),
                              _InfoRow(
                                icon: Icons.numbers,
                                label: 'Account Number',
                                value: accounts[0].accountNumber,
                              ),
                              const SizedBox(height: 8),
                              _InfoRow(
                                icon: Icons.location_on_outlined,
                                label: 'Branch',
                                value: accounts[0].branch,
                              ),
                              const SizedBox(height: 16),

                              // Delete button
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(
                                      color: AppColors.error,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Remove Bank Account',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onPressed: () => _delete(accounts[0]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // No account — show single add button
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.account_balance_outlined,
                                size: 60,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No bank account added yet.',
                                style: TextStyle(color: AppColors.textGrey),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.green,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Add Bank Account',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  onPressed: () => _showDialog(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// Info row widget
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  // Builds a row with an icon, label, and value for displaying bank account details
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.textGrey, size: 16),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ],
  );
}

// Simple text field
class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final TextInputType keyboard;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.keyboard = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    keyboardType: keyboard,
    style: const TextStyle(color: Colors.white),
    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
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
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.green, width: 2),
      ),
    ),
  );
}
