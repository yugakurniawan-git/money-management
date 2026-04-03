import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../providers/cold_money_provider.dart';
import '../common/glass_container.dart';
import '../common/animated_number.dart';

class ColdMoneyCard extends StatelessWidget {
  final ColdMoneyResult data;
  const ColdMoneyCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'id_ID');

    if (data.monthsOfData == 0) {
      return GlassContainer(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withAlpha(40),
            AppColors.primaryLight.withAlpha(20),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                color: AppColors.textSecondary, size: 40),
            const SizedBox(height: 12),
            Text(
              'Import data transaksi untuk\nmenghitung uang dingin kamu',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(60),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.savings_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Uang Dingin',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${data.monthsOfData} bulan data',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Rp ', style: TextStyle(color: Colors.white70, fontSize: 16)),
              AnimatedNumber(
                value: data.coldMoney,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Bisa diinvestasikan',
            style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _DetailRow(
                  label: 'Pemasukan/bln',
                  value: 'Rp ${fmt.format(data.avgMonthlyIncome)}',
                  color: AppColors.income,
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Pengeluaran/bln',
                  value: 'Rp ${fmt.format(data.avgMonthlyExpense)}',
                  color: AppColors.expense,
                ),
                Divider(color: Colors.white.withAlpha(20), height: 16),
                _DetailRow(
                  label: 'Saldo saat ini',
                  value: 'Rp ${fmt.format(data.currentBalance)}',
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Dana darurat (3×expense)',
                  value: '- Rp ${fmt.format(data.emergencyBuffer)}',
                  color: AppColors.warning,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _DetailRow(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
