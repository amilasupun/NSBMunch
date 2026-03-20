import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nsbmunch/models/payment_card_model.dart';
import 'package:nsbmunch/models/bank_account_model.dart';

class PaymentService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  // student payment cards and staff payment cards
  Stream<List<PaymentCard>> getMyCards() {
    return _db
        .collection('payment_cards')
        .where('userId', isEqualTo: _uid)
        .snapshots()
        .map((s) => s.docs.map((d) => PaymentCard.fromDoc(d)).toList());
  }

  Future<void> addCard(PaymentCard card) async {
    await _db.collection('payment_cards').add(card.toMap());
  }

  Future<void> updateCard(PaymentCard card) async {
    await _db.collection('payment_cards').doc(card.id).update(card.toMap());
  }

  Future<void> deleteCard(String cardId) async {
    await _db.collection('payment_cards').doc(cardId).delete();
  }

  Future<void> toggleCard(String cardId, bool isActive) async {
    await _db.collection('payment_cards').doc(cardId).update({
      'isActive': isActive,
    });
  }

  // Get first active card
  Future<PaymentCard?> getActiveCard() async {
    final snap = await _db
        .collection('payment_cards')
        .where('userId', isEqualTo: _uid)
        .where('isActive', isEqualTo: true)
        .get();
    if (snap.docs.isEmpty) return null;
    return PaymentCard.fromDoc(snap.docs.first);
  }

  // Shop bank accounts
  Stream<List<BankAccount>> getShopBankAccounts(String shopId) {
    return _db
        .collection('bank_accounts')
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map((s) => s.docs.map((d) => BankAccount.fromDoc(d)).toList());
  }

  Future<List<BankAccount>> getShopBankAccountsOnce(String shopId) async {
    final snap = await _db
        .collection('bank_accounts')
        .where('shopId', isEqualTo: shopId)
        .get();
    return snap.docs.map((d) => BankAccount.fromDoc(d)).toList();
  }

  Future<void> addBankAccount(BankAccount account) async {
    await _db.collection('bank_accounts').add(account.toMap());
  }

  Future<void> updateBankAccount(BankAccount account) async {
    await _db
        .collection('bank_accounts')
        .doc(account.id)
        .update(account.toMap());
  }

  Future<void> deleteBankAccount(String id) async {
    await _db.collection('bank_accounts').doc(id).delete();
  }
}
