import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import 'transaction_provider.dart';

// ── CategoryPrediction ────────────────────────────────────────────────────────

class CategoryPrediction {
  final String categoryId;
  final double avg;
  final double currentSpent;
  final double predicted;
  final double progressFraction;

  const CategoryPrediction({
    required this.categoryId,
    required this.avg,
    required this.currentSpent,
    required this.predicted,
    required this.progressFraction,
  });

  bool get isAboveAverage => predicted > avg && avg > 0;

  double get pctOfAvg => avg > 0 ? predicted / avg : 0;

  double get currentProgressPct => avg > 0 ? (currentSpent / avg).clamp(0.0, 2.0) : 0;
}

// ── SpendingPrediction ────────────────────────────────────────────────────────

class SpendingPrediction {
  final double avgMonthlyExpense;
  final double currentMonthExpense;
  final double predictedTotal;
  final int daysPassed;
  final int daysInMonth;
  final double progressFraction;
  final Map<String, double> categoryAvg;
  final Map<String, double> categoryCurrentSpent;

  const SpendingPrediction({
    required this.avgMonthlyExpense,
    required this.currentMonthExpense,
    required this.predictedTotal,
    required this.daysPassed,
    required this.daysInMonth,
    required this.progressFraction,
    required this.categoryAvg,
    required this.categoryCurrentSpent,
  });

  double get differenceFromAvg => predictedTotal - avgMonthlyExpense;

  bool get isAboveAverage => avgMonthlyExpense > 0 && predictedTotal > avgMonthlyExpense * 1.05;

  double get percentageVsAvg =>
      avgMonthlyExpense > 0 ? predictedTotal / avgMonthlyExpense : 1.0;

  List<CategoryPrediction> get topCategoryPredictions {
    final allCategories = <String>{
      ...categoryAvg.keys,
      ...categoryCurrentSpent.keys,
    };

    final predictions = allCategories.map((catId) {
      final avg = categoryAvg[catId] ?? 0;
      final current = categoryCurrentSpent[catId] ?? 0;
      final predicted = progressFraction > 0 ? current / progressFraction : current;
      return CategoryPrediction(
        categoryId: catId,
        avg: avg,
        currentSpent: current,
        predicted: predicted,
        progressFraction: progressFraction,
      );
    }).toList();

    predictions.sort((a, b) => b.predicted.compareTo(a.predicted));
    return predictions.take(5).toList();
  }
}

// ── spendingPredictionProvider ────────────────────────────────────────────────

final spendingPredictionProvider = Provider<SpendingPrediction>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? [];
  final now = DateTime.now();
  final thisYear = now.year;
  final thisMonth = now.month;

  final daysInMonth = DateUtils.getDaysInMonth(thisYear, thisMonth);
  final daysPassed = now.day;
  final progressFraction = daysPassed / daysInMonth;

  // Current month expenses
  final currentExpenses = transactions.where((txn) =>
      txn.isExpense &&
      txn.transactionDate.year == thisYear &&
      txn.transactionDate.month == thisMonth);

  double currentMonthTotal = 0;
  final Map<String, double> categoryCurrentSpent = {};
  for (final txn in currentExpenses) {
    currentMonthTotal += txn.amount;
    final key = txn.categoryId.isEmpty ? 'Lainnya' : txn.categoryId;
    categoryCurrentSpent[key] = (categoryCurrentSpent[key] ?? 0) + txn.amount;
  }

  // Past 3 complete months
  final Map<String, Map<String, double>> monthlyCategories = {};
  final Map<String, double> monthlyTotals = {};

  for (int i = 1; i <= 3; i++) {
    int year = thisYear;
    int month = thisMonth - i;
    while (month <= 0) {
      month += 12;
      year -= 1;
    }
    final key = '$year-$month';
    monthlyCategories[key] = {};
    monthlyTotals[key] = 0;

    final monthExpenses = transactions.where((txn) =>
        txn.isExpense &&
        txn.transactionDate.year == year &&
        txn.transactionDate.month == month);

    for (final txn in monthExpenses) {
      monthlyTotals[key] = (monthlyTotals[key] ?? 0) + txn.amount;
      final catKey = txn.categoryId.isEmpty ? 'Lainnya' : txn.categoryId;
      monthlyCategories[key]![catKey] =
          (monthlyCategories[key]![catKey] ?? 0) + txn.amount;
    }
  }

  // Average monthly expense
  double totalPast = 0;
  for (final v in monthlyTotals.values) {
    totalPast += v;
  }
  final avgMonthlyExpense = monthlyTotals.isNotEmpty ? totalPast / monthlyTotals.length : 0.0;

  // Average per category
  final Map<String, double> categoryAvg = {};
  final allCatIds = <String>{};
  for (final m in monthlyCategories.values) {
    allCatIds.addAll(m.keys);
  }
  for (final catId in allCatIds) {
    double sum = 0;
    for (final m in monthlyCategories.values) {
      sum += m[catId] ?? 0;
    }
    categoryAvg[catId] = sum / monthlyCategories.length;
  }

  // Predicted total
  final predictedTotal = progressFraction > 0
      ? currentMonthTotal / progressFraction
      : currentMonthTotal;

  return SpendingPrediction(
    avgMonthlyExpense: avgMonthlyExpense,
    currentMonthExpense: currentMonthTotal,
    predictedTotal: predictedTotal,
    daysPassed: daysPassed,
    daysInMonth: daysInMonth,
    progressFraction: progressFraction,
    categoryAvg: categoryAvg,
    categoryCurrentSpent: categoryCurrentSpent,
  );
});

// ── LeakItem & LeakReport ─────────────────────────────────────────────────────

class LeakItem {
  final String categoryId;
  final int transactionCount;
  final double totalAmount;
  final double avgAmount;

  const LeakItem({
    required this.categoryId,
    required this.transactionCount,
    required this.totalAmount,
    required this.avgAmount,
  });
}

class LeakReport {
  final List<LeakItem> leaks;
  final double totalLeakAmount;
  final int totalLeakTransactions;

  const LeakReport({
    required this.leaks,
    required this.totalLeakAmount,
    required this.totalLeakTransactions,
  });

  bool get hasLeaks => leaks.isNotEmpty;
}

// ── leakDetectorProvider ──────────────────────────────────────────────────────

final leakDetectorProvider =
    Provider.family<LeakReport, DateTime>((ref, month) {
  final transactions = ref.watch(transactionsProvider).value ?? [];

  final monthExpenses = transactions.where((txn) =>
      txn.isExpense &&
      txn.transactionDate.year == month.year &&
      txn.transactionDate.month == month.month);

  // Group by categoryId
  final Map<String, List<TransactionModel>> grouped = {};
  for (final txn in monthExpenses) {
    final key = txn.categoryId.isEmpty ? 'Lainnya' : txn.categoryId;
    grouped.putIfAbsent(key, () => []).add(txn);
  }

  final leaks = <LeakItem>[];
  for (final entry in grouped.entries) {
    final catId = entry.key;
    final txns = entry.value;
    final count = txns.length;
    final total = txns.fold<double>(0, (sum, t) => sum + t.amount);
    final avg = total / count;

    // Criteria: count >= 3 AND (avg < 300000 OR count >= 5)
    if (count >= 3 && (avg < 300000 || count >= 5)) {
      leaks.add(LeakItem(
        categoryId: catId,
        transactionCount: count,
        totalAmount: total,
        avgAmount: avg,
      ));
    }
  }

  // Sort by totalAmount desc
  leaks.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

  final totalLeakAmount = leaks.fold<double>(0, (sum, l) => sum + l.totalAmount);
  final totalLeakTransactions = leaks.fold<int>(0, (sum, l) => sum + l.transactionCount);

  return LeakReport(
    leaks: leaks,
    totalLeakAmount: totalLeakAmount,
    totalLeakTransactions: totalLeakTransactions,
  );
});
