import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nsbmunch/core/constants/app_colors.dart';
import 'package:nsbmunch/core/services/order_service.dart';
import 'package:nsbmunch/core/services/payment_service.dart';
import 'package:nsbmunch/models/cart_item_model.dart';
import 'package:nsbmunch/models/scheduled_order_model.dart';
import 'package:nsbmunch/models/payment_card_model.dart';
import 'package:nsbmunch/screens/student/payment_details_screen.dart';

// Schedule Order page where students can schedule their cart items for later pickup and payment
class ScheduleOrderPage extends StatefulWidget {
  final List<CartItem> cart;

  const ScheduleOrderPage({super.key, required this.cart});

  @override
  State<ScheduleOrderPage> createState() => _ScheduleOrderPageState();
}

class _ScheduleOrderPageState extends State<ScheduleOrderPage> {
  final _orderService = OrderService();
  final _paymentService = PaymentService();

  late List<Map<String, dynamic>> _items;

  DateTime _pickupDate = DateTime.now();

  int _pickupHour = 12;
  int _pickupMinute = 0;
  bool _pickupIsAm = false;

  int _payHour = 8;
  int _payMinute = 0;
  bool _payIsAm = true;

  PaymentCard? _activeCard;
  bool _loading = false;
  bool _cardLoaded = false;

  @override
  void initState() {
    super.initState();
    _items = widget.cart
        .map(
          (c) => {
            'name': c.menuItem.name,
            'price': c.menuItem.price,
            'quantity': c.quantity,
            'shopId': c.menuItem.shopId,
            'shopName': c.menuItem.shopName,
          },
        )
        .toList();
    _loadCard();
  }

  Future<void> _loadCard() async {
    setState(() => _cardLoaded = false);
    final card = await _paymentService.getActiveCard();
    if (mounted) {
      setState(() {
        _activeCard = card;
        _cardLoaded = true;
      });
    }
  }

  bool get _hasActiveCard => _activeCard != null && _activeCard!.isActive;

  double get _total => _items.fold(
    0.0,
    (s, i) => s + (i['price'] as double) * (i['quantity'] as int),
  );

  void _increase(int i) => setState(() {
    _items[i]['quantity'] = (_items[i]['quantity'] as int) + 1;
  });

  void _decrease(int i) => setState(() {
    if ((_items[i]['quantity'] as int) > 1) {
      _items[i]['quantity'] = (_items[i]['quantity'] as int) - 1;
    } else {
      _items.removeAt(i);
    }
  });

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _pickupDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.green),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _pickupDate = d);
  }

  bool get _isToday {
    final now = DateTime.now();
    return _pickupDate.year == now.year &&
        _pickupDate.month == now.month &&
        _pickupDate.day == now.day;
  }

  bool get _isScheduleValid {
    final pickupTotal = _to24hrMinutes(_pickupHour, _pickupMinute, _pickupIsAm);
    final payTotal = _to24hrMinutes(_payHour, _payMinute, _payIsAm);

    if (payTotal >= pickupTotal) return false;

    if (_isToday) {
      final now = TimeOfDay.now();
      final nowTotal = now.hour * 60 + now.minute;
      if (payTotal <= nowTotal) return false;
    }

    return true;
  }

  String get _scheduleValidationError {
    final pickupTotal = _to24hrMinutes(_pickupHour, _pickupMinute, _pickupIsAm);
    final payTotal = _to24hrMinutes(_payHour, _payMinute, _payIsAm);

    if (_isToday) {
      final now = TimeOfDay.now();
      final nowTotal = now.hour * 60 + now.minute;
      if (payTotal <= nowTotal) return 'Must be a future time (today)';
    }

    if (payTotal >= pickupTotal) return 'Must be before pickup time';

    return '';
  }

  int _to24hrMinutes(int hour12, int minute, bool isAm) {
    int h = hour12 % 12;
    if (!isAm) h += 12;
    return h * 60 + minute;
  }

  String _to24hr(int hour12, int minute, bool isAm) {
    int h = hour12 % 12;
    if (!isAm) h += 12;
    return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _displayTime(int hour12, int minute, bool isAm) {
    return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} ${isAm ? 'AM' : 'PM'}';
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _goToPaymentDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentDetailsScreen()),
    ).then((_) => _loadCard());
  }

  Future<void> _confirm() async {
    if (_items.isEmpty || !_hasActiveCard) return;

    if (!_isScheduleValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_scheduleValidationError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final pickupTimeStr = _to24hr(_pickupHour, _pickupMinute, _pickupIsAm);
      final paymentTimeStr = _to24hr(_payHour, _payMinute, _payIsAm);

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      final Map<String, String> shopNames = {};
      for (final item in _items) {
        final shopId = item['shopId'] as String? ?? '';
        final shopName = item['shopName'] as String? ?? '';
        grouped.putIfAbsent(shopId, () => []).add(item);
        shopNames[shopId] = shopName;
      }

      for (final entry in grouped.entries) {
        final shopId = entry.key;
        final shopItems = entry.value;
        final shopTotal = shopItems.fold(
          0.0,
          (s, i) => s + (i['price'] as double) * (i['quantity'] as int),
        );
        final order = ScheduledOrder(
          id: '',
          userId: uid,
          shopId: shopId,
          shopName: shopNames[shopId] ?? '',
          items: shopItems,
          totalPrice: shopTotal,
          pickupDate: _fmtDate(_pickupDate),
          pickupTime: pickupTimeStr,
          paymentTime: paymentTimeStr,
          paymentStatus: 'payment_pending',
          orderStatus: '',
          orderNumber: '',
          triggered: false,
          createdAt: DateTime.now(),
        );
        await _orderService.placeScheduledOrder(order);
      }

      if (!mounted) return;
      widget.cart.clear();
      Navigator.pop(context);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            grouped.length > 1
                ? '${grouped.length} orders scheduled! Auto-send at ${_displayTime(_payHour, _payMinute, _payIsAm)} on ${_fmtDate(_pickupDate)}.'
                : 'Order scheduled! Auto-send at ${_displayTime(_payHour, _payMinute, _payIsAm)} on ${_fmtDate(_pickupDate)}.',
          ),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // quick orders tab for students to view their recent no scheduled orders
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Schedule Order',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...List.generate(_items.length, (i) {
            final item = _items[i];
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Rs. ${(item['price'] as double).toStringAsFixed(2)} x ${item['quantity']}',
                          style: const TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _QtyBtn(icon: Icons.remove, onTap: () => _decrease(i)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '${item['quantity']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _QtyBtn(icon: Icons.add, onTap: () => _increase(i)),
                    ],
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          if (!_cardLoaded)
            _InfoRow(
              icon: Icons.hourglass_top,
              text: 'Checking payment card...',
              color: AppColors.textGrey,
            )
          else if (!_hasActiveCard)
            GestureDetector(
              onTap: _goToPaymentDetails,
              child: _InfoRow(
                icon: Icons.credit_card_off,
                text: 'No active card. Tap to add.',
                color: AppColors.error,
                hasBorder: true,
              ),
            )
          else
            _InfoRow(
              icon: Icons.credit_card,
              text: '${_activeCard!.bankName} ${_activeCard!.maskedNumber}',
              color: AppColors.green,
              hasBorder: true,
            ),

          const SizedBox(height: 14),

          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: AppColors.green,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Pickup Date',
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (_isToday) ...[
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Today',
                            style: TextStyle(
                              color: AppColors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        _fmtDate(_pickupDate),
                        style: const TextStyle(
                          color: AppColors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          _AmPmTimeSelector(
            label: 'Pickup Time',
            icon: Icons.access_time,
            hour: _pickupHour,
            minute: _pickupMinute,
            isAm: _pickupIsAm,
            onHourChanged: (v) => setState(() => _pickupHour = v!),
            onMinuteChanged: (v) => setState(() => _pickupMinute = v!),
            onAmPmChanged: (v) => setState(() => _pickupIsAm = v),
          ),
          const SizedBox(height: 10),

          _AmPmTimeSelector(
            label: 'Auto Payment Time',
            icon: Icons.payment,
            hour: _payHour,
            minute: _payMinute,
            isAm: _payIsAm,
            onHourChanged: (v) => setState(() => _payHour = v!),
            onMinuteChanged: (v) => setState(() => _payMinute = v!),
            onAmPmChanged: (v) => setState(() => _payIsAm = v),
            validationError: !_isScheduleValid
                ? _scheduleValidationError
                : null,
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Rs. ${_total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasActiveCard
                    ? AppColors.green
                    : AppColors.border,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _loading
                  ? null
                  : _hasActiveCard
                  ? _confirm
                  : _goToPaymentDetails,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _hasActiveCard
                          ? 'Confirm Schedule'
                          : 'Add Payment Card First',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// Time selector widget for pickup and payment time selection in schedule order page
class _AmPmTimeSelector extends StatelessWidget {
  final String label;
  final IconData icon;
  final int hour;
  final int minute;
  final bool isAm;
  final ValueChanged<int?> onHourChanged;
  final ValueChanged<int?> onMinuteChanged;
  final ValueChanged<bool> onAmPmChanged;
  final String? validationError;

  const _AmPmTimeSelector({
    required this.label,
    required this.icon,
    required this.hour,
    required this.minute,
    required this.isAm,
    required this.onHourChanged,
    required this.onMinuteChanged,
    required this.onAmPmChanged,
    this.validationError,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = validationError != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasError ? AppColors.error : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              if (hasError)
                Text(
                  validationError!,
                  style: const TextStyle(color: AppColors.error, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DropDown(
                  label: 'Hour',
                  value: hour,
                  items: List.generate(12, (i) => i + 1),
                  onChanged: onHourChanged,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  ':',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: _DropDown(
                  label: 'Min',
                  value: minute,
                  items: [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55],
                  onChanged: onMinuteChanged,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  _AmPmBtn(
                    label: 'AM',
                    selected: isAm,
                    onTap: () => onAmPmChanged(true),
                  ),
                  const SizedBox(height: 4),
                  _AmPmBtn(
                    label: 'PM',
                    selected: !isAm,
                    onTap: () => onAmPmChanged(false),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Text(
                '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}\n${isAm ? 'AM' : 'PM'}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: hasError ? AppColors.error : AppColors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Individual order card widget
class _AmPmBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AmPmBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  // Order card widget for displaying individual orders in the quick orders screen
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.green : Colors.black,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? AppColors.green : AppColors.border,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.textGrey,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

// Individual order card widget for displaying individual orders in the quick orders screen
class _DropDown extends StatelessWidget {
  final String label;
  final int value;
  final List<int> items;
  final ValueChanged<int?> onChanged;
  const _DropDown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  // Dropdown widget for selecting hours and minutes in the time selector
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    initialValue: value,
    dropdownColor: AppColors.surface,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textGrey, fontSize: 11),
      filled: true,
      fillColor: Colors.black,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    ),
    items: items
        .map(
          (i) => DropdownMenuItem(
            value: i,
            child: Text(i.toString().padLeft(2, '0')),
          ),
        )
        .toList(),
    onChanged: onChanged,
  );
}

// Individual order card widget for displaying individual orders in the quick orders screen
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool hasBorder;
  const _InfoRow({
    required this.icon,
    required this.text,
    required this.color,
    this.hasBorder = false,
  });
  // Info row widget for displaying payment card info and loading state in the schedule order page
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: hasBorder ? Border.all(color: color) : null,
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: color, fontSize: 13)),
        ),
      ],
    ),
  );
}

// Individual order card widget for displaying individual orders in the quick orders screen
class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: AppColors.green, size: 18),
    ),
  );
}
