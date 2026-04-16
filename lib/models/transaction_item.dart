class TransactionItem {
  final String name;
  final double amount;
  final String categoryId;

  TransactionItem({
    required this.name,
    required this.amount,
    required this.categoryId,
  });

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      name: map['name'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      categoryId: map['categoryId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'categoryId': categoryId,
    };
  }

  TransactionItem copyWith({
    String? name,
    double? amount,
    String? categoryId,
  }) {
    return TransactionItem(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
    );
  }
}
