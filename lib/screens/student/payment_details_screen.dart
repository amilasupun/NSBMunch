import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nsbmunch/core/constants/app_colors.dart';
import 'package:nsbmunch/core/services/payment_service.dart';
import 'package:nsbmunch/models/payment_card_model.dart';

// Payment Details Screen for students to manage their payment cards
class PaymentDetailsScreen extends StatefulWidget {
  const PaymentDetailsScreen({super.key});

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

// This screen allows students to add, edit, delete, and toggle their payment cards.
class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  final _paymentService = PaymentService();

  void _showCardDialog({PaymentCard? existing}) {
    String selectedType = existing?.type ?? 'debit';

    final bankCtrl = TextEditingController(text: existing?.bankName ?? '');
    final holderCtrl = TextEditingController(text: existing?.cardHolder ?? '');
    final numCtrl = TextEditingController(
      text: existing != null ? _addSpaces(existing.cardNumber) : '',
    );
    final expiryCtrl = TextEditingController(text: existing?.expiryDate ?? '');
    final cvvCtrl = TextEditingController(text: existing?.cvv ?? '');

    bool loading = false;
    bool cvvHidden = true;
    final formKey = GlobalKey<FormState>();
    // Dialog for adding/editing a payment card
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
            existing == null ? 'Add Card' : 'Edit Card',
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
                  // Debit / Credit selector
                  Row(
                    children: [
                      _TypeBtn(
                        label: 'Debit',
                        selected: selectedType == 'debit',
                        onTap: () => setS(() => selectedType = 'debit'),
                      ),
                      const SizedBox(width: 10),
                      _TypeBtn(
                        label: 'Credit',
                        selected: selectedType == 'credit',
                        onTap: () => setS(() => selectedType = 'credit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _Field(
                    ctrl: bankCtrl,
                    label: 'Bank Name',
                    hint: 'e.g. Commercial Bank',
                  ),
                  const SizedBox(height: 10),

                  _Field(
                    ctrl: holderCtrl,
                    label: 'Card Holder Name',
                    hint: 'Name as on card',
                    keyboard: TextInputType.name,
                    capitalize: TextCapitalization.words,
                  ),
                  const SizedBox(height: 10),

                  // Card Number
                  TextFormField(
                    controller: numCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: Colors.white,
                      letterSpacing: 2,
                      fontSize: 15,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _CardNumberFormatter(),
                      LengthLimitingTextInputFormatter(19),
                    ],
                    validator: (v) {
                      final digits = (v ?? '').replaceAll(' ', '');
                      if (digits.isEmpty) return 'Required';
                      // FIX: curly braces added
                      if (digits.length != 16) {
                        return 'Enter 16-digit card number';
                      }
                      return null;
                    },
                    decoration: _inputDeco(
                      label: 'Card Number',
                      hint: '1111 2222 3333 4444',
                      prefix: const Icon(
                        Icons.credit_card,
                        color: AppColors.green,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Expiry + CVV
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: expiryCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            _ExpiryFormatter(),
                            LengthLimitingTextInputFormatter(5),
                          ],
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v.length < 5) return 'MM/YY';
                            return null;
                          },
                          decoration: _inputDeco(
                            label: 'Expiry',
                            hint: 'MM/YY',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: cvvCtrl,
                          keyboardType: TextInputType.number,
                          obscureText: cvvHidden,
                          style: const TextStyle(color: Colors.white),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v.length < 3) return '3 digits';
                            return null;
                          },
                          decoration: _inputDeco(
                            label: 'CVV',
                            hint: '•••',
                            suffix: GestureDetector(
                              onTap: () => setS(() => cvvHidden = !cvvHidden),
                              child: Icon(
                                cvvHidden
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppColors.textGrey,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setS(() => loading = true);
                      try {
                        final uid =
                            FirebaseAuth.instance.currentUser?.uid ?? '';
                        final rawNum = numCtrl.text.replaceAll(' ', '');
                        final card = PaymentCard(
                          id: existing?.id ?? '',
                          userId: uid,
                          type: selectedType,
                          bankName: bankCtrl.text.trim(),
                          cardHolder: holderCtrl.text.trim(),
                          cardNumber: rawNum,
                          expiryDate: expiryCtrl.text.trim(),
                          cvv: cvvCtrl.text.trim(),
                          isActive: existing?.isActive ?? true,
                        );
                        if (existing == null) {
                          await _paymentService.addCard(card);
                        } else {
                          await _paymentService.updateCard(card);
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

  // Delete card confirmation dialog
  void _deleteCard(PaymentCard card) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Card?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Delete ${card.bankName} ${card.maskedNumber}?',
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
              await _paymentService.deleteCard(card.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Helper to add spaces in card number for better readability in the text field
  String _addSpaces(String raw) {
    final digits = raw.replaceAll(' ', '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  // Main build method for the Payment Details screen
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
                'Payment Details',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: StreamBuilder<List<PaymentCard>>(
        stream: _paymentService.getMyCards(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.green),
            );
          }

          final cards = snap.data ?? [];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.add_card, color: Colors.white),
                    label: const Text(
                      'Add New Card',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _showCardDialog(),
                  ),
                ),
              ),
              Expanded(
                child: cards.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.credit_card_off,
                              size: 60,
                              color: AppColors.textGrey,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No cards added.',
                              style: TextStyle(color: AppColors.textGrey),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tap "Add New Card" to get started.',
                              style: TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: cards.length,
                        itemBuilder: (ctx, i) => _CardTile(
                          card: cards[i],
                          paymentService: _paymentService,
                          onEdit: () => _showCardDialog(existing: cards[i]),
                          onDelete: () => _deleteCard(cards[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Widget for displaying each payment card with options to edit, delete, and toggle active status
class _CardTile extends StatelessWidget {
  final PaymentCard card;
  final PaymentService paymentService;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CardTile({
    required this.card,
    required this.paymentService,
    required this.onEdit,
    required this.onDelete,
  });
  // Card display with masked number, bank name, and expiry date, along with controls to edit, delete, and toggle active status
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: card.isActive ? AppColors.green : AppColors.border,
          width: card.isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 170,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              gradient: LinearGradient(
                colors: card.isActive
                    ? [const Color(0xFF1A6B3C), const Color(0xFF0D3D22)]
                    : [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      card.bankName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        card.type.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  card.maskedNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CARD HOLDER',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 9,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          card.cardHolder.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'EXPIRES',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 9,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          card.expiryDate,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Controls
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Switch(
                  value: card.isActive,
                  activeThumbColor: AppColors.green,
                  activeTrackColor: AppColors.green.withValues(alpha: 0.3),
                  inactiveThumbColor: AppColors.textGrey,
                  onChanged: (val) => paymentService.toggleCard(card.id, val),
                ),
                Text(
                  card.isActive ? 'Active' : 'Disabled',
                  style: TextStyle(
                    color: card.isActive ? AppColors.green : AppColors.textGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                    size: 20,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  // Button for selecting card type (debit or credit) in the add/edit card dialog
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.green : Colors.black,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.green : AppColors.border,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textGrey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),
  );
}

// Input decoration for text fields in the add/edit card dialog
InputDecoration _inputDeco({
  required String label,
  required String hint,
  Widget? prefix,
  Widget? suffix,
}) => InputDecoration(
  labelText: label,
  hintText: hint,
  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
  filled: true,
  fillColor: Colors.black,
  prefixIcon: prefix,
  suffixIcon: suffix,
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
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AppColors.error),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AppColors.error, width: 2),
  ),
);

// Widget for selecting card type (debit or credit) in the add/edit card dialog
class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final TextInputType keyboard;
  final TextCapitalization capitalize;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.keyboard = TextInputType.text,
    this.capitalize = TextCapitalization.none,
  });
  // Input field for bank name and card holder name in the add/edit card dialog
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    keyboardType: keyboard,
    textCapitalization: capitalize,
    style: const TextStyle(color: Colors.white),
    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
    decoration: _inputDeco(label: label, hint: hint),
  );
}

// Formatter to add spaces in card number input for better readability
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final str = buf.toString();
    return newValue.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

// Formatter to add spaces in card number input for better readability
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll('/', '');
    if (digits.length > 4) return oldValue;
    String str = digits;
    if (digits.length > 2) {
      str = '${digits.substring(0, 2)}/${digits.substring(2)}';
    }
    return newValue.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}
