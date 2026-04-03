import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction.dart';
import '../services/firebase_service.dart';

final firebaseServiceProvider =
    Provider<FirebaseService>((ref) => FirebaseService());

// Watch auth state — providers only load when user is logged in
final authUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final transactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(firebaseServiceProvider).getTransactions();
});

final transactionsByAccountProvider =
    StreamProvider.family<List<TransactionModel>, String>((ref, accountId) {
  return ref
      .watch(firebaseServiceProvider)
      .getTransactions(accountId: accountId);
});

// Total saldo kumulatif dari semua transaksi sepanjang waktu
final totalBalanceProvider = Provider<_TotalBalance>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? [];
  double income = 0;
  double expense = 0;
  for (final txn in transactions) {
    if (txn.isIncome) {
      income += txn.amount;
    } else {
      expense += txn.amount;
    }
  }
  return _TotalBalance(totalIncome: income, totalExpense: expense);
});

class _TotalBalance {
  final double totalIncome;
  final double totalExpense;
  _TotalBalance({required this.totalIncome, required this.totalExpense});
  double get balance => totalIncome - totalExpense;
}

// Monthly summary
final monthlySummaryProvider =
    Provider.family<MonthlySummary, DateTime>((ref, month) {
  final transactions = ref.watch(transactionsProvider).value ?? [];

  final monthTransactions = transactions.where((txn) =>
      txn.transactionDate.year == month.year &&
      txn.transactionDate.month == month.month);

  double totalIncome = 0;
  double totalExpense = 0;

  for (final txn in monthTransactions) {
    if (txn.isIncome) {
      totalIncome += txn.amount;
    } else {
      totalExpense += txn.amount;
    }
  }

  return MonthlySummary(
    month: month,
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    transactions: monthTransactions.toList(),
  );
});

class MonthlySummary {
  final DateTime month;
  final double totalIncome;
  final double totalExpense;
  final List<TransactionModel> transactions;

  MonthlySummary({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.transactions,
  });

  double get balance => totalIncome - totalExpense;
}

// Category breakdown for pie chart
final categoryBreakdownProvider =
    Provider.family<Map<String, double>, DateTime>((ref, month) {
  final transactions = ref.watch(transactionsProvider).value ?? [];

  final expenses = transactions.where((txn) =>
      txn.isExpense &&
      txn.transactionDate.year == month.year &&
      txn.transactionDate.month == month.month);

  final breakdown = <String, double>{};
  for (final txn in expenses) {
    final key = txn.categoryId.isEmpty ? 'Lainnya' : txn.categoryId;
    breakdown[key] = (breakdown[key] ?? 0) + txn.amount;
  }

  return breakdown;
});
