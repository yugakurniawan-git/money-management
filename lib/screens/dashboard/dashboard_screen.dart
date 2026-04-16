import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/insight_provider.dart';
import '../../providers/health_score_provider.dart';
import '../../providers/goal_provider.dart';
import '../../widgets/charts/monthly_bar_chart.dart';
import '../../widgets/charts/category_pie_chart.dart';

import '../../widgets/common/transaction_tile.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/animated_number.dart';
import '../../widgets/common/staggered_list_animation.dart';
import '../insights/insights_screen.dart';
import '../report/report_screen.dart';
import '../goals/goals_screen.dart';
import '../receipt_scanner_screen.dart';

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
    final prediction = ref.watch(spendingPredictionProvider);
    final leakReport = ref.watch(leakDetectorProvider(now));
    final healthScore = ref.watch(healthScoreProvider);
    final goals = ref.watch(goalsProvider).value ?? [];
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ReceiptScannerScreen(),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        label: const Text('Scan Struk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
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

                // Health Score Card
                StaggeredListItem(
                  index: 2,
                  child: _HealthScoreCard(healthScore: healthScore),
                ),

                // Budget Overview
                if (budgetStatuses.isNotEmpty) ...[
                  StaggeredListItem(
                    index: 3,
                    child: _SectionHeader(title: 'BUDGET BULAN INI'),
                  ),
                  StaggeredListItem(
                    index: 4,
                    child: _BudgetOverviewCard(
                      summary: budgetSummary,
                      statuses: budgetStatuses,
                      categoryNames: categoryMap,
                    ),
                  ),
                ],

                // Goals Preview
                Builder(builder: (context) {
                  final activeGoals =
                      goals.where((g) => !g.isCompleted).take(2).toList();
                  if (goals.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StaggeredListItem(
                        index: 5,
                        child: _SectionHeader(title: 'TUJUAN KEUANGAN'),
                      ),
                      StaggeredListItem(
                        index: 6,
                        child: GlassContainer(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              ...activeGoals.map((goal) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(goal.emoji,
                                                style: const TextStyle(
                                                    fontSize: 18)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                goal.title,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                            ),
                                            Text(
                                              '${(goal.progress * 100).toStringAsFixed(0)}%',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(3),
                                          child: LinearProgressIndicator(
                                            value: goal.progress,
                                            backgroundColor:
                                                AppColors.darkCard,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    AppColors.primary),
                                            minHeight: 5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const GoalsScreen()),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ShaderMask(
                                      shaderCallback: (bounds) =>
                                          AppColors.primaryGradient
                                              .createShader(bounds),
                                      child: const Text(
                                        'Lihat Semua →',
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
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }),

                // Insights Preview
                StaggeredListItem(
                  index: budgetStatuses.isNotEmpty ? 7 : 5,
                  child: _SectionHeader(title: 'ANALISIS BULAN INI'),
                ),
                StaggeredListItem(
                  index: budgetStatuses.isNotEmpty ? 5 : 3,
                  child: _InsightPreviewCard(
                    prediction: prediction,
                    leakReport: leakReport,
                  ),
                ),

                // Bar Chart
                StaggeredListItem(
                  index: budgetStatuses.isNotEmpty ? 6 : 4,
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
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ReportScreen()),
                            ),
                            child: ShaderMask(
                              shaderCallback: (bounds) =>
                                  AppColors.primaryGradient.createShader(bounds),
                              child: const Text(
                                '📊 Laporan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
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

// ── HealthScoreCard ───────────────────────────────────────────────────────────

class _HealthScoreCard extends StatelessWidget {
  final HealthScore healthScore;
  const _HealthScoreCard({required this.healthScore});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InsightsScreen()),
      ),
      child: GlassContainer(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Score + Grade
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${healthScore.score}',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: healthScore.gradeColor,
                  ),
                ),
                Text(
                  healthScore.gradeEmoji,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 2),
                Text(
                  healthScore.grade,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: healthScore.gradeColor,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: 72,
                  child: Text(
                    healthScore.gradeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: healthScore.gradeColor,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Factor bars
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SKOR KESEHATAN KEUANGAN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...healthScore.factors.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  f.label,
                                  style: const TextStyle(fontSize: 10),
                                ),
                                Text(
                                  '${f.score}/${f.maxScore}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: f.maxScore > 0
                                    ? f.score / f.maxScore
                                    : 0,
                                backgroundColor: AppColors.darkCard,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    healthScore.gradeColor),
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Tap untuk detail →',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

// ── Insight Preview Card ──────────────────────────────────────────────────────

class _InsightPreviewCard extends StatelessWidget {
  final SpendingPrediction prediction;
  final LeakReport leakReport;

  const _InsightPreviewCard({
    required this.prediction,
    required this.leakReport,
  });

  static final _compact =
      NumberFormat.compactCurrency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final pct = prediction.percentageVsAvg;
    final bool isCheaper = pct < 0.95;
    final bool isExpensive = pct > 1.05;

    final Color predColor = isCheaper
        ? const Color(0xFF43A047)
        : isExpensive
            ? const Color(0xFFFF9800)
            : AppColors.primary;

    final String predLabel = isCheaper
        ? 'Lebih Hemat 🎉'
        : isExpensive
            ? 'Lebih Boros ⚠️'
            : 'Sesuai Rata-rata';

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Prediction mini card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: predColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: predColor.withAlpha(77)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('📈', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            'Prediksi',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _compact.format(prediction.predictedTotal),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: predColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        predLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: predColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Leak mini card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: leakReport.hasLeaks
                        ? AppColors.expense.withAlpha(26)
                        : const Color(0xFF43A047).withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: leakReport.hasLeaks
                          ? AppColors.expense.withAlpha(77)
                          : const Color(0xFF43A047).withAlpha(77),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('💸', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            'Uang Bocor',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        leakReport.hasLeaks
                            ? _compact.format(leakReport.totalLeakAmount)
                            : 'Aman',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: leakReport.hasLeaks
                              ? AppColors.expense
                              : const Color(0xFF43A047),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        leakReport.hasLeaks
                            ? '${leakReport.leaks.length} kategori bocor'
                            : 'Tidak ada kebocoran',
                        style: TextStyle(
                          fontSize: 10,
                          color: leakReport.hasLeaks
                              ? AppColors.expense
                              : const Color(0xFF43A047),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InsightsScreen(),
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.primaryGradient.createShader(bounds),
                  child: const Text(
                    'Lihat Detail Analisis →',
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
        ],
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
