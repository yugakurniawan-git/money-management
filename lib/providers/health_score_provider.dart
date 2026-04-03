import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'transaction_provider.dart';

class HealthScoreFactor {
  final String label;
  final int score;
  final int maxScore;
  final String detail;
  final String tip;

  const HealthScoreFactor({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.detail,
    required this.tip,
  });
}

class HealthScore {
  final int score;
  final String grade;
  final String gradeLabel;
  final Color gradeColor;
  final List<HealthScoreFactor> factors;

  const HealthScore({
    required this.score,
    required this.grade,
    required this.gradeLabel,
    required this.gradeColor,
    required this.factors,
  });

  String get gradeEmoji {
    switch (grade) {
      case 'A':
        return '🌟';
      case 'B':
        return '✅';
      case 'C':
        return '⚡';
      case 'D':
        return '⚠️';
      default:
        return '🚨';
    }
  }
}

final healthScoreProvider = Provider<HealthScore>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? [];
  final now = DateTime.now();

  // ── Factor 1: Rasio Pengeluaran vs Pemasukan (40 poin) ──────────────────────
  // Hitung rata-rata 3 bulan terakhir
  double totalIncome3 = 0;
  double totalExpense3 = 0;
  int monthsWithData = 0;

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
      if (txn.transactionDate.year == year && txn.transactionDate.month == month) {
        if (txn.isIncome) {
          monthIncome += txn.amount;
        } else {
          monthExpense += txn.amount;
        }
      }
    }
    if (monthIncome > 0 || monthExpense > 0) {
      monthsWithData++;
      totalIncome3 += monthIncome;
      totalExpense3 += monthExpense;
    }
  }

  final avgIncome = monthsWithData > 0 ? totalIncome3 / monthsWithData : 0.0;
  final avgExpense = monthsWithData > 0 ? totalExpense3 / monthsWithData : 0.0;

  int ratioScore;
  String ratioDetail;
  String ratioTip;

  if (avgIncome <= 0) {
    ratioScore = 0;
    ratioDetail = 'Tidak ada data pemasukan';
    ratioTip = 'Catat pemasukan kamu secara rutin';
  } else {
    final ratio = avgExpense / avgIncome;
    if (ratio <= 0.50) {
      ratioScore = 40;
      ratioDetail =
          'Sangat baik! Hanya ${(ratio * 100).toStringAsFixed(0)}% dari pemasukan dibelanjakan';
      ratioTip = 'Pertahankan kebiasaan hemat ini';
    } else if (ratio <= 0.60) {
      ratioScore = 32;
      ratioDetail =
          '${(ratio * 100).toStringAsFixed(0)}% dari pemasukan dibelanjakan';
      ratioTip = 'Coba kurangi pengeluaran 5-10% lagi';
    } else if (ratio <= 0.70) {
      ratioScore = 24;
      ratioDetail =
          '${(ratio * 100).toStringAsFixed(0)}% dari pemasukan dibelanjakan';
      ratioTip = 'Identifikasi pengeluaran yang bisa dikurangi';
    } else if (ratio <= 0.80) {
      ratioScore = 12;
      ratioDetail =
          '${(ratio * 100).toStringAsFixed(0)}% dari pemasukan dibelanjakan – terlalu tinggi';
      ratioTip = 'Buat budget ketat untuk kategori besar';
    } else {
      ratioScore = 0;
      ratioDetail =
          'Pengeluaran melebihi ${(ratio * 100).toStringAsFixed(0)}% pemasukan!';
      ratioTip = 'Segera evaluasi semua pengeluaran rutin';
    }
  }

  final factorRatio = HealthScoreFactor(
    label: 'Rasio Pengeluaran',
    score: ratioScore,
    maxScore: 40,
    detail: ratioDetail,
    tip: ratioTip,
  );

  // ── Factor 2: Dana Darurat (30 poin) ────────────────────────────────────────
  double totalAllIncome = 0;
  double totalAllExpense = 0;
  for (final txn in transactions) {
    if (txn.isIncome) {
      totalAllIncome += txn.amount;
    } else {
      totalAllExpense += txn.amount;
    }
  }
  final currentBalance = totalAllIncome - totalAllExpense;
  final emergencyBuffer = avgExpense * 3; // 3 bulan pengeluaran

  int emergencyScore;
  String emergencyDetail;
  String emergencyTip;

  if (emergencyBuffer <= 0) {
    emergencyScore = 0;
    emergencyDetail = 'Tidak ada data pengeluaran';
    emergencyTip = 'Mulai catat pengeluaran rutin kamu';
  } else {
    final ratio = currentBalance / emergencyBuffer;
    if (ratio >= 2.0) {
      emergencyScore = 30;
      emergencyDetail =
          'Dana darurat ${(ratio).toStringAsFixed(1)}x – cukup untuk 6+ bulan';
      emergencyTip = 'Pertimbangkan investasi untuk kelebihan dana';
    } else if (ratio >= 1.0) {
      emergencyScore = 20;
      emergencyDetail =
          'Dana darurat ${(ratio).toStringAsFixed(1)}x – cukup untuk 3 bulan';
      emergencyTip = 'Tingkatkan tabungan hingga 6 bulan pengeluaran';
    } else if (ratio >= 0.5) {
      emergencyScore = 10;
      emergencyDetail =
          'Dana darurat ${(ratio).toStringAsFixed(1)}x – masih kurang';
      emergencyTip = 'Target minimal 3 bulan pengeluaran sebagai dana darurat';
    } else {
      emergencyScore = 0;
      emergencyDetail = currentBalance < 0
          ? 'Saldo negatif! Segera evaluasi keuangan'
          : 'Dana darurat sangat minim';
      emergencyTip = 'Prioritaskan membangun dana darurat minimal 1 bulan dulu';
    }
  }

  final factorEmergency = HealthScoreFactor(
    label: 'Dana Darurat',
    score: emergencyScore,
    maxScore: 30,
    detail: emergencyDetail,
    tip: emergencyTip,
  );

  // ── Factor 3: Tren Pengeluaran (20 poin) ────────────────────────────────────
  double thisMonthExpense = 0;
  double lastMonthExpense = 0;

  for (final txn in transactions) {
    if (txn.isExpense) {
      if (txn.transactionDate.year == now.year &&
          txn.transactionDate.month == now.month) {
        thisMonthExpense += txn.amount;
      }
    }
  }

  int lastYear = now.year;
  int lastMonth = now.month - 1;
  if (lastMonth <= 0) {
    lastMonth += 12;
    lastYear -= 1;
  }
  for (final txn in transactions) {
    if (txn.isExpense &&
        txn.transactionDate.year == lastYear &&
        txn.transactionDate.month == lastMonth) {
      lastMonthExpense += txn.amount;
    }
  }

  int trendScore;
  String trendDetail;
  String trendTip;

  if (lastMonthExpense <= 0) {
    trendScore = 10;
    trendDetail = 'Tidak ada data bulan lalu';
    trendTip = 'Tetap pantau pengeluaran setiap bulan';
  } else {
    final changePct = (thisMonthExpense - lastMonthExpense) / lastMonthExpense;
    if (changePct < -0.05) {
      trendScore = 20;
      trendDetail =
          'Pengeluaran turun ${(changePct.abs() * 100).toStringAsFixed(0)}% vs bulan lalu';
      trendTip = 'Bagus! Pertahankan tren positif ini';
    } else if (changePct.abs() <= 0.05) {
      trendScore = 10;
      trendDetail = 'Pengeluaran stabil dibanding bulan lalu';
      trendTip = 'Coba cari peluang untuk lebih berhemat';
    } else if (changePct <= 0.20) {
      trendScore = 5;
      trendDetail =
          'Pengeluaran naik ${(changePct * 100).toStringAsFixed(0)}% vs bulan lalu';
      trendTip = 'Identifikasi penyebab kenaikan pengeluaran';
    } else {
      trendScore = 0;
      trendDetail =
          'Pengeluaran naik ${(changePct * 100).toStringAsFixed(0)}%! Perlu perhatian';
      trendTip = 'Segera review semua pengeluaran bulan ini';
    }
  }

  final factorTrend = HealthScoreFactor(
    label: 'Tren Pengeluaran',
    score: trendScore,
    maxScore: 20,
    detail: trendDetail,
    tip: trendTip,
  );

  // ── Factor 4: Konsistensi Ada Income (10 poin) ───────────────────────────────
  int monthsWithIncome = 0;
  for (int i = 1; i <= 3; i++) {
    int year = now.year;
    int month = now.month - i;
    while (month <= 0) {
      month += 12;
      year -= 1;
    }
    final hasIncome = transactions.any((txn) =>
        txn.isIncome &&
        txn.transactionDate.year == year &&
        txn.transactionDate.month == month);
    if (hasIncome) monthsWithIncome++;
  }

  int consistencyScore;
  String consistencyDetail;
  String consistencyTip;

  if (monthsWithIncome == 3) {
    consistencyScore = 10;
    consistencyDetail = 'Pemasukan konsisten selama 3 bulan terakhir';
    consistencyTip = 'Pertahankan konsistensi catatan pemasukan';
  } else if (monthsWithIncome == 2) {
    consistencyScore = 6;
    consistencyDetail = 'Pemasukan tercatat di 2 dari 3 bulan terakhir';
    consistencyTip = 'Pastikan semua pemasukan dicatat setiap bulan';
  } else if (monthsWithIncome == 1) {
    consistencyScore = 3;
    consistencyDetail = 'Pemasukan hanya tercatat di 1 bulan terakhir';
    consistencyTip = 'Rutin catat semua sumber pemasukan';
  } else {
    consistencyScore = 0;
    consistencyDetail = 'Tidak ada pemasukan tercatat dalam 3 bulan';
    consistencyTip = 'Mulai catat pemasukan kamu dari sekarang';
  }

  final factorConsistency = HealthScoreFactor(
    label: 'Konsistensi Income',
    score: consistencyScore,
    maxScore: 10,
    detail: consistencyDetail,
    tip: consistencyTip,
  );

  // ── Hitung total skor ────────────────────────────────────────────────────────
  final totalScore =
      ratioScore + emergencyScore + trendScore + consistencyScore;

  String grade;
  String gradeLabel;
  Color gradeColor;

  if (totalScore >= 80) {
    grade = 'A';
    gradeLabel = 'Sangat Sehat';
    gradeColor = const Color(0xFF43A047);
  } else if (totalScore >= 65) {
    grade = 'B';
    gradeLabel = 'Sehat';
    gradeColor = const Color(0xFF66BB6A);
  } else if (totalScore >= 50) {
    grade = 'C';
    gradeLabel = 'Cukup';
    gradeColor = const Color(0xFFFFB300);
  } else if (totalScore >= 35) {
    grade = 'D';
    gradeLabel = 'Perlu Perhatian';
    gradeColor = const Color(0xFFFF9800);
  } else {
    grade = 'E';
    gradeLabel = 'Kritis';
    gradeColor = const Color(0xFFE53935);
  }

  return HealthScore(
    score: totalScore,
    grade: grade,
    gradeLabel: gradeLabel,
    gradeColor: gradeColor,
    factors: [factorRatio, factorEmergency, factorTrend, factorConsistency],
  );
});
