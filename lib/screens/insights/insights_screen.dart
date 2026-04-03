import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/insight_provider.dart';
import '../../providers/category_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/glass_container.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analisis Keuangan'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Info',
              onPressed: () => _showHelpSheet(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '📈 Prediksi'),
              Tab(text: '💸 Uang Bocor'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PredictionTab(),
            _LeakTab(),
          ],
        ),
      ),
    );
  }

  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _InsightsHelpSheet(),
    );
  }
}

// ── Prediction Tab ────────────────────────────────────────────────────────────

class _PredictionTab extends ConsumerWidget {
  const _PredictionTab();

  static final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prediction = ref.watch(spendingPredictionProvider);
    final categoryMap = ref.watch(categoryMapProvider);
    final categoryNames = ref.watch(categoryNameMapProvider);

    final pct = prediction.percentageVsAvg;
    final bool isCheaper = pct < 0.95;
    final bool isExpensive = pct > 1.05;

    final Color statusColor = isCheaper
        ? const Color(0xFF43A047)
        : isExpensive
            ? const Color(0xFFFF9800)
            : AppColors.primary;

    final String statusLabel = isCheaper
        ? 'Lebih Hemat 🎉'
        : isExpensive
            ? 'Lebih Boros ⚠️'
            : 'Sesuai';

    final progressValue = prediction.predictedTotal > 0
        ? (prediction.currentMonthExpense / prediction.predictedTotal).clamp(0.0, 1.0)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Hero card
        GlassContainer(
          gradient: AppColors.primaryGradient,
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PROYEKSI AKHIR BULAN',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _currency.format(prediction.predictedTotal),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Rata-rata 3 bulan: ${_currency.format(prediction.avgMonthlyExpense)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(51),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withAlpha(128)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Hari ke-${prediction.daysPassed} dari ${prediction.daysInMonth} • '
                'Sudah keluar ${_currency.format(prediction.currentMonthExpense)}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),

        // Progress section
        GlassContainer(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sudah terpakai: ${_currency.format(prediction.currentMonthExpense)} '
                'dari proyeksi ${_currency.format(prediction.predictedTotal)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: AppColors.darkCard,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sisa ${prediction.daysInMonth - prediction.daysPassed} hari lagi',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // Per category section
        if (prediction.topCategoryPredictions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'PREDIKSI PER KATEGORI',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ...prediction.topCategoryPredictions.map((catPred) {
            final cat = categoryMap[catPred.categoryId];
            final name = categoryNames[catPred.categoryId] ?? catPred.categoryId;
            final barValue = catPred.currentProgressPct.clamp(0.0, 1.0);
            return GlassContainer(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cat?.color.withAlpha(51) ?? AppColors.darkCard,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        cat?.icon ?? '🏷️',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (catPred.isAboveAverage)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE53935).withAlpha(38),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Di atas rata-rata',
                                  style: TextStyle(
                                    color: Color(0xFFE53935),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rata-rata: ${_currency.format(catPred.avg)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Proyeksi: ${_currency.format(catPred.predicted)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: barValue,
                            backgroundColor: AppColors.darkCard,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              catPred.isAboveAverage
                                  ? const Color(0xFFE53935)
                                  : const Color(0xFF43A047),
                            ),
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],

        // Info card
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.darkCard.withAlpha(128),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline,
                  size: 16, color: Color(0xFFFFD93D)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Prediksi ini dihitung dari rata-rata pengeluaran 3 bulan terakhir dan kecepatan pengeluaran bulan ini.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Leak Tab ──────────────────────────────────────────────────────────────────

class _LeakTab extends ConsumerWidget {
  const _LeakTab();

  static final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  static final _compact =
      NumberFormat.compactCurrency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final leakReport = ref.watch(leakDetectorProvider(now));
    final categoryMap = ref.watch(categoryMapProvider);
    final categoryNames = ref.watch(categoryNameMapProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Section header
        GlassContainer(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('💸', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Uang Bocor',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pengeluaran kecil berulang yang sering tidak disadari',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (!leakReport.hasLeaks) ...[
          // Empty state
          GlassContainer(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                const Text('✅', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                const Text(
                  'Tidak ada kebocoran ditemukan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pengeluaran bulan ini tidak ada yang terdeteksi sebagai kebocoran.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ] else ...[
          // Summary card
          GlassContainer(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
            ),
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOTAL BOCOR BULAN INI',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _currency.format(leakReport.totalLeakAmount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dari ${leakReport.totalLeakTransactions} transaksi di '
                  '${leakReport.leaks.length} kategori',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          // Leak items
          ...leakReport.leaks.map((leak) {
            final cat = categoryMap[leak.categoryId];
            final name = categoryNames[leak.categoryId] ?? leak.categoryId;
            final maxBar = leakReport.totalLeakAmount > 0
                ? leak.totalAmount / leakReport.totalLeakAmount
                : 1.0;

            return GlassContainer(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: cat?.color.withAlpha(51) ?? AppColors.darkCard,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            cat?.icon ?? '🏷️',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.expense.withAlpha(38),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${leak.transactionCount}x transaksi',
                          style: const TextStyle(
                            color: AppColors.expense,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rata-rata ${_compact.format(leak.avgAmount)} / transaksi',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _currency.format(leak.totalAmount),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxBar.clamp(0.0, 1.0),
                      backgroundColor: AppColors.darkCard,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.expense),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],

        // Tip card
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.darkCard.withAlpha(128),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.tips_and_updates_outlined,
                  size: 16, color: Color(0xFFFFD93D)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tips: Pengeluaran kecil yang sering berulang bisa terakumulasi besar. '
                  'Pertimbangkan untuk membatasi frekuensinya.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Help Sheet ────────────────────────────────────────────────────────────────

class _InsightsHelpSheet extends StatelessWidget {
  const _InsightsHelpSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withAlpha(77),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Cara Kerja Analisis',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _HelpSection(
            icon: '📈',
            title: 'Prediksi Pengeluaran',
            description:
                'Kami menghitung rata-rata pengeluaran kamu dari 3 bulan terakhir yang '
                'sudah selesai. Kemudian, berdasarkan kecepatan pengeluaran bulan ini '
                '(berapa banyak yang sudah keluar dibagi dengan berapa persen bulan yang '
                'sudah berlalu), kami memproyeksikan total pengeluaran di akhir bulan.\n\n'
                'Contoh: Jika hari ini tanggal 10 (33% bulan) dan sudah keluar Rp 500.000, '
                'maka proyeksi akhir bulan adalah sekitar Rp 1.500.000.',
          ),
          const SizedBox(height: 16),
          _HelpSection(
            icon: '💸',
            title: 'Uang Bocor Detector',
            description:
                'Fitur ini mendeteksi kategori pengeluaran yang memiliki transaksi '
                'berulang kecil-kecil yang mungkin tidak kamu sadari.\n\n'
                'Suatu kategori terdeteksi "bocor" jika:\n'
                '• Memiliki 3+ transaksi di bulan ini, DAN\n'
                '• Rata-rata per transaksi di bawah Rp 300.000, ATAU memiliki 5+ transaksi\n\n'
                'Pengeluaran seperti kopi, parkir, atau jajan kecil yang terjadi hampir '
                'setiap hari bisa terakumulasi sangat besar di akhir bulan.',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Mengerti'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final String icon;
  final String title;
  final String description;

  const _HelpSection({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkCard.withAlpha(77),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
