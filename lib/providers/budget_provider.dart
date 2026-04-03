import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget.dart';
import '../services/firebase_service.dart';
import 'transaction_provider.dart';

final budgetsProvider = StreamProvider<List<BudgetModel>>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return Stream.value([]);
  return FirebaseService().getBudgets();
});

/// Status budget setiap kategori untuk bulan tertentu
class BudgetStatus {
  final BudgetModel budget;
  final double spent;

  BudgetStatus({required this.budget, required this.spent});

  double get limit => budget.monthlyLimit;
  double get remaining => limit - spent;
  double get percentage => limit > 0 ? (spent / limit).clamp(0.0, 9.9) : 0.0;
  bool get isOver => spent > limit;
  bool get isWarning => percentage >= 0.8 && !isOver;
  bool get isSafe => percentage < 0.6;

  Color get statusColor {
    if (isOver) return const Color(0xFFE53935);
    if (isWarning) return const Color(0xFFFF9800);
    if (percentage >= 0.6) return const Color(0xFFFFB300);
    return const Color(0xFF43A047);
  }

  String get statusLabel {
    if (isOver) return 'Over Budget';
    if (isWarning) return 'Hampir Habis';
    if (percentage >= 0.6) return 'Waspada';
    return 'Aman';
  }
}

final budgetStatusProvider =
    Provider.family<List<BudgetStatus>, DateTime>((ref, month) {
  final budgets = ref.watch(budgetsProvider).value ?? [];
  final transactions = ref.watch(transactionsProvider).value ?? [];

  // Pengeluaran bulan ini per kategori
  final spent = <String, double>{};
  for (final txn in transactions) {
    if (txn.isExpense &&
        txn.transactionDate.year == month.year &&
        txn.transactionDate.month == month.month) {
      spent[txn.categoryId] = (spent[txn.categoryId] ?? 0) + txn.amount;
    }
  }

  return budgets
      .map((b) => BudgetStatus(
            budget: b,
            spent: spent[b.categoryId] ?? 0,
          ))
      .toList()
    ..sort((a, b) => b.percentage.compareTo(a.percentage));
});

/// Ringkasan total budget bulan ini
class BudgetSummary {
  final double totalLimit;
  final double totalSpent;
  final int overCount;
  final int warningCount;

  BudgetSummary({
    required this.totalLimit,
    required this.totalSpent,
    required this.overCount,
    required this.warningCount,
  });

  double get percentage => totalLimit > 0 ? totalSpent / totalLimit : 0;
  double get remaining => totalLimit - totalSpent;
}

final budgetSummaryProvider =
    Provider.family<BudgetSummary, DateTime>((ref, month) {
  final statuses = ref.watch(budgetStatusProvider(month));
  return BudgetSummary(
    totalLimit: statuses.fold(0, (s, b) => s + b.limit),
    totalSpent: statuses.fold(0, (s, b) => s + b.spent),
    overCount: statuses.where((b) => b.isOver).length,
    warningCount: statuses.where((b) => b.isWarning).length,
  );
});
