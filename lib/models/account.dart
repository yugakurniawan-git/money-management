import 'package:cloud_firestore/cloud_firestore.dart';

class AccountModel {
  final String id;
  final String bankName;
  final String accountNumber;
  final String ownerName;
  final double balance;
  final DateTime balanceUpdatedAt;

  AccountModel({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.ownerName,
    this.balance = 0,
    required this.balanceUpdatedAt,
  });

  factory AccountModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AccountModel(
      id: doc.id,
      bankName: data['bankName'] ?? 'BCA',
      accountNumber: data['accountNumber'] ?? '',
      ownerName: data['ownerName'] ?? '',
      balance: (data['balance'] ?? 0).toDouble(),
      balanceUpdatedAt:
          (data['balanceUpdatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ownerName': ownerName,
      'balance': balance,
      'balanceUpdatedAt': Timestamp.fromDate(balanceUpdatedAt),
    };
  }

  String get maskedAccountNumber {
    if (accountNumber.length <= 4) return accountNumber;
    return '****${accountNumber.substring(accountNumber.length - 4)}';
  }
}
