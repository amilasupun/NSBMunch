import 'package:cloud_firestore/cloud_firestore.dart';

class BankAccount {
  final String id;
  final String shopId;
  final String accountHolder;
  final String accountNumber;
  final String bankName;
  final String branch;

  BankAccount({
    required this.id,
    required this.shopId,
    required this.accountHolder,
    required this.accountNumber,
    required this.bankName,
    required this.branch,
  });

  factory BankAccount.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BankAccount(
      id: doc.id,
      shopId: d['shopId'] ?? '',
      accountHolder: d['accountHolder'] ?? '',
      accountNumber: d['accountNumber'] ?? '',
      bankName: d['bankName'] ?? '',
      branch: d['branch'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'shopId': shopId,
    'accountHolder': accountHolder,
    'accountNumber': accountNumber,
    'bankName': bankName,
    'branch': branch,
  };
}
