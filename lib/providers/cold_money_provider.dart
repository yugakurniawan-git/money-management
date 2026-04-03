import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'transaction_provider.dart';

class ColdMoneyResult {
  final double avgMonthlyIncome;
  final double avgMonthlyExpense;
  final double currentBalance;
  final double emergencyBuffer;
  final double coldMoney;
  final int monthsOfData;

  ColdMoneyResult({
    required this.avgMonthlyIncome,
    required this.avgMonthlyExpense,
    required this.currentBalance,
    required this.emergencyBuffer,
    required this.coldMoney,
    required this.monthsOfData,
  });

  static ColdMoneyResult empty() => ColdMoneyResult(
        avgMonthlyIncome: 0,
        avgMonthlyExpense: 0,
        currentBalance: 0,
        emergencyBuffer: 0,
        coldMoney: 0,
        monthsOfData: 0,
      );
}

/// Buffer multiplier: default 3 months (adjustable by user)
final emergencyBufferMonthsProvider = StateProvider<int>((ref) => 3);

final coldMoneyProvider = Provider<ColdMoneyResult>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? [];
  if (transactions.isEmpty) return ColdMoneyResult.empty();

  final bufferMonths = ref.watch(emergencyBufferMonthsProvider);
  final now = DateTime.now();

  // Get last 3 months of data
  final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);
  final recentTxns = transactions
      .where((t) => t.transactionDate.isAfter(threeMonthsAgo))
      .toList();

  if (recentTxns.isEmpty) return ColdMoneyResult.empty();

  // Calculate monthly income & expense
  final months = <String, _MonthData>{};
  for (final txn in recentTxns) {
    final key =
        '${txn.transactionDate.year}-${txn.transactionDate.month}';
    months.putIfAbsent(key, () => _MonthData());
    if (txn.isIncome) {
      months[key]!.income += txn.amount;
    } else {
      months[key]!.expense += txn.amount;
    }
  }

  final monthCount = months.length;
  if (monthCount == 0) return ColdMoneyResult.empty();

  final totalIncome = months.values.fold(0.0, (s, m) => s + m.income);
  final totalExpense = months.values.fold(0.0, (s, m) => s + m.expense);
  final avgIncome = totalIncome / monthCount;
  final avgExpense = totalExpense / monthCount;

  // Current balance = most recent transaction's balanceAfter
  // (transactions are sorted newest first)
  final currentBalance = transactions.first.balanceAfter;

  final emergencyBuffer = avgExpense * bufferMonths;
  final coldMoney =
      (currentBalance - emergencyBuffer).clamp(0, double.infinity);

  return ColdMoneyResult(
    avgMonthlyIncome: avgIncome,
    avgMonthlyExpense: avgExpense,
    currentBalance: currentBalance,
    emergencyBuffer: emergencyBuffer,
    coldMoney: coldMoney.toDouble(),
    monthsOfData: monthCount,
  );
});

class _MonthData {
  double income = 0;
  double expense = 0;
}
