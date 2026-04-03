import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String accountId;
  final double amount;
  final String description;
  final String rawDescription;
  final String categoryId;
  final String transactionType; // "credit" or "debit"
  final DateTime transactionDate;
  final double balanceAfter;
  final String note;
  final String importHash;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.description,
    required this.rawDescription,
    required this.categoryId,
    required this.transactionType,
    required this.transactionDate,
    required this.balanceAfter,
    this.note = '',
    required this.importHash,
    required this.createdAt,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      accountId: data['accountId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      description: data['description'] ?? '',
      rawDescription: data['rawDescription'] ?? '',
      categoryId: data['categoryId'] ?? '',
      transactionType: data['transactionType'] ?? 'debit',
      transactionDate: (data['transactionDate'] as Timestamp).toDate(),
      balanceAfter: (data['balanceAfter'] ?? 0).toDouble(),
      note: data['note'] ?? '',
      importHash: data['importHash'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'accountId': accountId,
      'amount': amount,
      'description': description,
      'rawDescription': rawDescription,
      'categoryId': categoryId,
      'transactionType': transactionType,
      'transactionDate': Timestamp.fromDate(transactionDate),
      'balanceAfter': balanceAfter,
      'note': note,
      'importHash': importHash,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  TransactionModel copyWith({
    String? id,
    String? accountId,
    double? amount,
    String? description,
    String? rawDescription,
    String? categoryId,
    String? transactionType,
    DateTime? transactionDate,
    double? balanceAfter,
    String? note,
    String? importHash,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      rawDescription: rawDescription ?? this.rawDescription,
      categoryId: categoryId ?? this.categoryId,
      transactionType: transactionType ?? this.transactionType,
      transactionDate: transactionDate ?? this.transactionDate,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      note: note ?? this.note,
      importHash: importHash ?? this.importHash,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isExpense => transactionType == 'debit';
  bool get isIncome => transactionType == 'credit';
}
