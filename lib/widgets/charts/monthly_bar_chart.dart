import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../theme/app_colors.dart';

class MonthlyBarChart extends StatelessWidget {
  final List<TransactionModel> transactions;

  const MonthlyBarChart({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      return DateTime(now.year, now.month - (5 - i), 1);
    });

    final data = months.map((month) {
      return transactions
          .where((txn) =>
              txn.isExpense &&
              txn.transactionDate.year == month.year &&
              txn.transactionDate.month == month.month)
          .fold<double>(0, (sum, txn) => sum + txn.amount);
    }).toList();

    final maxY =
        data.isEmpty ? 1000000.0 : (data.reduce((a, b) => a > b ? a : b) * 1.2);

    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 1000000 : maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 10,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final formatter = NumberFormat.compactCurrency(
                  locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
              return BarTooltipItem(
                formatter.format(rod.toY),
                const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (value, meta) {
                final formatter = NumberFormat.compact(locale: 'id_ID');
                return Text(
                  formatter.format(value),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final month = months[value.toInt()];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('MMM', 'id_ID').format(month),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.glassBorderDark,
            strokeWidth: 0.5,
          ),
        ),
        barGroups: List.generate(
          months.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: data[i],
                gradient: AppColors.primaryGradient,
                width: 22,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
