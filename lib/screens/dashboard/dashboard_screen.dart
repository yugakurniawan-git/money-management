import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/budget_provider.dart';
import '../../widgets/charts/monthly_bar_chart.dart';
import '../../widgets/charts/category_pie_chart.dart';

import '../../widgets/common/transaction_tile.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/animated_number.dart';
import '../../widgets/common/staggered_list_animation.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static String _fmt(double v) =>
      NumberFormat.compactCurrency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(v);

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
    final totalBalance = ref.watch(totalBalanceProvider);
    final transactions = ref.watch(transactionsProvider);
    final categoryMap = ref.watch(categoryNameMapProvider);
    final budgetSummary = ref.watch(budgetSummaryProvider(now));
    final budgetStatuses = ref.watch(budgetStatusProvider(now));
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
                        Row(
                          children: [
                            const Text(
                              'TOTAL SALDO',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(38),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Semua Waktu',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AnimatedNumber(
                          value: totalBalance.balance,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bulan ini: +${_fmt(summary.totalIncome)}  /  -${_fmt(summary.totalExpense)}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _MiniStat(
                                label: 'Total Masuk',
                                value: totalBalance.totalIncome,
                                icon: Icons.arrow_downward,
                                color: AppColors.income,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _MiniStat(
                                label: 'Total Keluar',
                                value: totalBalance.totalExpense,
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

                // Budget Overview
                if (budgetStatuses.isNotEmpty) ...[
                  StaggeredListItem(
                    index: 2,
                    child: _SectionHeader(title: 'BUDGET BULAN INI'),
                  ),
                  StaggeredListItem(
                    index: 3,
                    child: _BudgetOverviewCard(
                      summary: budgetSummary,
                      statuses: budgetStatuses,
                      categoryNames: categoryMap,
                    ),
                  ),
                ],

                // Bar Chart
                StaggeredListItem(
                  index: budgetStatuses.isNotEmpty ? 4 : 2,
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

// ── Budget Overview Card (for dashboard) ─────────────────────────────────────

class _BudgetOverviewCard extends StatelessWidget {
  final BudgetSummary summary;
  final List<BudgetStatus> statuses;
  final Map<String, String> categoryNames;

  const _BudgetOverviewCard({
    required this.summary,
    required this.statuses,
    required this.categoryNames,
  });

  @override
  Widget build(BuildContext context) {
    final pct = summary.percentage.clamp(0.0, 1.0);
    final overallColor = summary.overCount > 0
        ? const Color(0xFFE53935)
        : summary.warningCount > 0
            ? const Color(0xFFFF9800)
            : const Color(0xFF43A047);

    final compactCurrency = NumberFormat.compactCurrency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );

    // Show top 3 statuses sorted by percentage desc
    final topStatuses = statuses.take(3).toList();

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${compactCurrency.format(summary.totalSpent)} / ${compactCurrency.format(summary.totalLimit)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                '${(pct * 100).toStringAsFixed(0)}% terpakai',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.darkCard,
              valueColor: AlwaysStoppedAnimation<Color>(overallColor),
              minHeight: 6,
            ),
          ),

          if (summary.overCount > 0 || summary.warningCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (summary.overCount > 0) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${summary.overCount} over budget',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (summary.warningCount > 0) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF9800),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${summary.warningCount} hampir habis',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFFF9800),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],

          if (topStatuses.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...topStatuses.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        _categoryLabel(s),
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: s.percentage.clamp(0.0, 1.0),
                          backgroundColor: AppColors.darkCard,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(s.statusColor),
                          minHeight: 5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(s.percentage * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: s.statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _categoryLabel(BudgetStatus s) =>
      categoryNames[s.budget.categoryId] ?? 'Kategori';
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
