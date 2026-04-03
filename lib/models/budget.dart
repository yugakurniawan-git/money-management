import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetModel {
  final String id;
  final String categoryId;
  final double monthlyLimit;
  final DateTime createdAt;

  BudgetModel({
    required this.id,
    required this.categoryId,
    required this.monthlyLimit,
    required this.createdAt,
  });

  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BudgetModel(
      id: doc.id,
      categoryId: d['categoryId'] ?? '',
      monthlyLimit: (d['monthlyLimit'] ?? 0).toDouble(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'categoryId': categoryId,
        'monthlyLimit': monthlyLimit,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  BudgetModel copyWith({String? categoryId, double? monthlyLimit}) =>
      BudgetModel(
        id: id,
        categoryId: categoryId ?? this.categoryId,
        monthlyLimit: monthlyLimit ?? this.monthlyLimit,
        createdAt: createdAt,
      );
}
