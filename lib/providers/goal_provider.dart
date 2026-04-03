import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/goal.dart';
import '../services/firebase_service.dart';
import 'transaction_provider.dart';

final goalsProvider = StreamProvider<List<GoalModel>>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return Stream.value([]);
  return FirebaseService().getGoals();
});

class GoalStats {
  final GoalModel goal;
  final double monthlySavingNeeded;
  final int? monthsToGoal;
  final double currentMonthlySaving;

  const GoalStats({
    required this.goal,
    required this.monthlySavingNeeded,
    required this.monthsToGoal,
    required this.currentMonthlySaving,
  });

  bool get isOnTrack =>
      monthlySavingNeeded > 0 && currentMonthlySaving >= monthlySavingNeeded;
}

final goalStatsProvider =
    Provider.family<GoalStats, GoalModel>((ref, goal) {
  final transactions = ref.watch(transactionsProvider).value ?? [];
  final now = DateTime.now();

  // Hitung rata-rata saving (income - expense) per bulan dari 3 bulan terakhir
  double totalSaving = 0;
  int validMonths = 0;

  for (int i = 1; i <= 3; i++) {
    int year = now.year;
    int month = now.month - i;
    while (month <= 0) {
      month += 12;
      year -= 1;
    }
    double monthIncome = 0;
    double monthExpense = 0;
    for (final txn in transactions) {
      if (txn.transactionDate.year == year &&
          txn.transactionDate.month == month) {
        if (txn.isIncome) {
          monthIncome += txn.amount;
        } else {
          monthExpense += txn.amount;
        }
      }
    }
    if (monthIncome > 0 || monthExpense > 0) {
      validMonths++;
      totalSaving += (monthIncome - monthExpense);
    }
  }

  final currentMonthlySaving =
      validMonths > 0 ? totalSaving / validMonths : 0.0;

  // Hitung monthlySavingNeeded berdasarkan targetDate
  double monthlySavingNeeded = 0;
  if (goal.targetDate != null && !goal.isCompleted) {
    final monthsLeft = (goal.targetDate!.year - now.year) * 12 +
        (goal.targetDate!.month - now.month);
    if (monthsLeft > 0) {
      monthlySavingNeeded = goal.remaining / monthsLeft;
    }
  }

  // Hitung monthsToGoal berdasarkan currentMonthlySaving
  int? monthsToGoal;
  if (!goal.isCompleted &&
      currentMonthlySaving > 0 &&
      goal.remaining > 0) {
    monthsToGoal = (goal.remaining / currentMonthlySaving).ceil();
  }

  return GoalStats(
    goal: goal,
    monthlySavingNeeded: monthlySavingNeeded,
    monthsToGoal: monthsToGoal,
    currentMonthlySaving: currentMonthlySaving,
  );
});
