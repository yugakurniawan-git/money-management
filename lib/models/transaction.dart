import 'package:cloud_firestore/cloud_firestore.dart';
import 'transaction_item.dart';

class TransactionModel {
  final String id;
  final String accountId;
  final double amount;
  final String description;
  final String rawDescription;
  final String categoryId;
  final String transactionType; // "credit", "debit", or "transfer"
  final String? toAccountId;
  final List<TransactionItem>? items;
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
    this.toAccountId,
    this.items,
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
      toAccountId: data['toAccountId'],
      items: data['items'] != null
          ? (data['items'] as List).map((i) => TransactionItem.fromMap(i as Map<String, dynamic>)).toList()
          : null,
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
      if (toAccountId != null) 'toAccountId': toAccountId,
      if (items != null) 'items': items!.map((i) => i.toMap()).toList(),
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
    String? toAccountId,
    List<TransactionItem>? items,
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
      toAccountId: toAccountId ?? this.toAccountId,
      items: items ?? this.items,
      transactionDate: transactionDate ?? this.transactionDate,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      note: note ?? this.note,
      importHash: importHash ?? this.importHash,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isExpense => transactionType == 'debit';
  bool get isIncome => transactionType == 'credit';
  bool get isTransfer => transactionType == 'transfer';
}
