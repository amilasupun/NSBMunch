import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentCard {
  final String id;
  final String userId;
  final String type;
  final String bankName;
  final String cardHolder;
  final String cardNumber;
  final String expiryDate;
  final String cvv;
  final bool isActive;

  PaymentCard({
    required this.id,
    required this.userId,
    required this.type,
    required this.bankName,
    required this.cardHolder,
    required this.cardNumber,
    required this.expiryDate,
    required this.cvv,
    required this.isActive,
  });

  // automatically get last 4 digits for display
  String get lastFour => cardNumber.length >= 4
      ? cardNumber.substring(cardNumber.length - 4)
      : cardNumber;

  // masked card number for display
  String get maskedNumber {
    final digits = cardNumber.replaceAll(' ', '');
    if (digits.length < 16) return cardNumber;
    return '•••• •••• •••• ${digits.substring(12)}';
  }

  factory PaymentCard.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PaymentCard(
      id: doc.id,
      userId: d['userId'] ?? '',
      type: d['type'] ?? 'debit',
      bankName: d['bankName'] ?? '',
      cardHolder: d['cardHolder'] ?? '',
      cardNumber: d['cardNumber'] ?? '',
      expiryDate: d['expiryDate'] ?? '',
      cvv: d['cvv'] ?? '',
      isActive: d['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'type': type,
    'bankName': bankName,
    'cardHolder': cardHolder,
    'cardNumber': cardNumber,
    'expiryDate': expiryDate,
    'cvv': cvv,
    'isActive': isActive,
  };

  PaymentCard copyWith({
    String? type,
    String? bankName,
    String? cardHolder,
    String? cardNumber,
    String? expiryDate,
    String? cvv,
    bool? isActive,
  }) => PaymentCard(
    id: id,
    userId: userId,
    type: type ?? this.type,
    bankName: bankName ?? this.bankName,
    cardHolder: cardHolder ?? this.cardHolder,
    cardNumber: cardNumber ?? this.cardNumber,
    expiryDate: expiryDate ?? this.expiryDate,
    cvv: cvv ?? this.cvv,
    isActive: isActive ?? this.isActive,
  );
}
