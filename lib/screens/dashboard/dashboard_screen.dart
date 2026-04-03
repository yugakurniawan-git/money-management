import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../widgets/charts/monthly_bar_chart.dart';
import '../../widgets/charts/category_pie_chart.dart';

import '../../widgets/common/transaction_tile.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/animated_number.dart';
import '../../widgets/common/staggered_list_animation.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final summary = ref.watch(monthlySummaryProvider(now));
    final transactions = ref.watch(transactionsProvider);
    final categoryMap = ref.watch(categoryNameMapProvider);
    return Scaffold(
      body: transactions.when(
        loading: () => const _DashboardEmpty(),
        error: (err, _) => const _DashboardEmpty(),
        data: (txnList) {
          final recentTxns = txnList.take(5).toList();

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(transactionsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                // Custom Header
                SafeArea(
                  bottom: false,
                  child: StaggeredListItem(
                    index: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _greeting(),
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Dashboard',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.person,
                                color: Colors.white, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Balance Card
                StaggeredListItem(
                  index: 1,
                  child: GlassContainer(
                    gradient: AppColors.primaryGradient,
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SALDO BULAN INI',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedNumber(
                          value: summary.balance,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _MiniStat(
                                label: 'Pemasukan',
                                value: summary.totalIncome,
                                icon: Icons.arrow_downward,
                                color: AppColors.income,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _MiniStat(
                                label: 'Pengeluaran',
                                value: summary.totalExpense,
                                icon: Icons.arrow_upward,
                                color: AppColors.expense,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Bar Chart
                StaggeredListItem(
                  index: 2,
                  child: _SectionHeader(title: 'PENGELUARAN 6 BULAN'),
                ),
                StaggeredListItem(
                  index: 3,
                  child: GlassContainer(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: SizedBox(
                      height: 200,
                      child: MonthlyBarChart(transactions: txnList),
                    ),
                  ),
                ),

                // Pie Chart
                StaggeredListItem(
                  index: 4,
                  child: _SectionHeader(title: 'BREAKDOWN KATEGORI'),
                ),
                StaggeredListItem(
                  index: 5,
                  child: GlassContainer(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: SizedBox(
                      height: 220,
                      child: CategoryPieChart(
                        breakdown:
                            ref.watch(categoryBreakdownProvider(now)),
                        categoryNames: categoryMap,
                      ),
                    ),
                  ),
                ),

                // Recent Transactions
                StaggeredListItem(
                  index: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SectionHeader(title: 'TRANSAKSI TERBARU'),
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppColors.primaryGradient.createShader(bounds),
                        child: const Text(
                          'Lihat Semua',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                if (recentTxns.isEmpty)
                  StaggeredListItem(
                    index: 7,
                    child: GlassContainer(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada transaksi',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Import CSV dari myBCA untuk memulai',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...recentTxns.asMap().entries.map((e) => StaggeredListItem(
                        index: 7 + e.key,
                        child: TransactionTile(
                          transaction: e.value,
                          categoryName:
                              categoryMap[e.value.categoryId] ?? 'Lainnya',
                        ),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(38),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
              AnimatedNumber(
                value: value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _DashboardEmpty extends StatelessWidget {
  const _DashboardEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.account_balance_wallet,
                color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          Text('Belum ada data',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Import CSV dari myBCA\nuntuk memulai.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
