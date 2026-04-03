import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/glass_container.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late DateTime _selectedMonth;
  final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _compact =
      NumberFormat.compactCurrency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  final _monthFmt = DateFormat('MMMM yyyy', 'id_ID');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _selectedMonth = next);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year &&
        _selectedMonth.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider).value ?? [];
    final categoryNames = ref.watch(categoryNameMapProvider);

    // Transaksi bulan ini
    final monthTxns = transactions.where((t) =>
        t.transactionDate.year == _selectedMonth.year &&
        t.transactionDate.month == _selectedMonth.month);

    double totalIncome = 0;
    double totalExpense = 0;
    final Map<String, double> categoryExpense = {};
    final Map<int, double> dayExpense = {}; // weekday 1-7
    double biggestAmount = 0;
    String biggestDesc = '';
    String biggestCat = '';

    for (final txn in monthTxns) {
      if (txn.isIncome) {
        totalIncome += txn.amount;
      } else {
        totalExpense += txn.amount;
        final cat = txn.categoryId.isEmpty ? 'Lainnya' : txn.categoryId;
        categoryExpense[cat] = (categoryExpense[cat] ?? 0) + txn.amount;
        final wd = txn.transactionDate.weekday; // 1=Mon..7=Sun
        dayExpense[wd] = (dayExpense[wd] ?? 0) + txn.amount;
        if (txn.amount > biggestAmount) {
          biggestAmount = txn.amount;
          biggestDesc = txn.description;
          biggestCat = categoryNames[txn.categoryId] ?? 'Lainnya';
        }
      }
    }

    final surplus = totalIncome - totalExpense;

    // Bulan lalu
    int prevYear = _selectedMonth.year;
    int prevMonth = _selectedMonth.month - 1;
    if (prevMonth <= 0) {
      prevMonth += 12;
      prevYear -= 1;
    }
    double prevExpense = 0;
    for (final txn in transactions) {
      if (txn.isExpense &&
          txn.transactionDate.year == prevYear &&
          txn.transactionDate.month == prevMonth) {
        prevExpense += txn.amount;
      }
    }

    double? expenseChangePct;
    if (prevExpense > 0) {
      expenseChangePct = (totalExpense - prevExpense) / prevExpense;
    }

    // Top 5 kategori
    final sortedCats = categoryExpense.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sortedCats.take(5).toList();

    // Hari paling boros
    String? borosDay;
    if (dayExpense.isNotEmpty) {
      final maxEntry =
          dayExpense.entries.reduce((a, b) => a.value > b.value ? a : b);
      const days = ['', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      borosDay = days[maxEntry.key];
    }

    // Rata-rata harian
    final daysInMonth = DateUtils.getDaysInMonth(
        _selectedMonth.year, _selectedMonth.month);
    final avgDaily = totalExpense / daysInMonth;

    // Kategori dengan transaksi terbanyak
    final Map<String, int> catCount = {};
    for (final txn in monthTxns) {
      if (txn.isExpense) {
        final cat = txn.categoryId.isEmpty ? 'Lainnya' : txn.categoryId;
        catCount[cat] = (catCount[cat] ?? 0) + 1;
      }
    }
    String? mostFrequentCat;
    if (catCount.isNotEmpty) {
      final maxCat =
          catCount.entries.reduce((a, b) => a.value > b.value ? a : b);
      mostFrequentCat = categoryNames[maxCat.key] ?? maxCat.key;
    }

    // 6 bulan trend data
    final trend6 = <_MonthSummary>[];
    for (int i = 5; i >= 0; i--) {
      int year = _selectedMonth.year;
      int month = _selectedMonth.month - i;
      while (month <= 0) {
        month += 12;
        year -= 1;
      }
      double exp = 0;
      double inc = 0;
      for (final txn in transactions) {
        if (txn.transactionDate.year == year &&
            txn.transactionDate.month == month) {
          if (txn.isExpense) exp += txn.amount;
          if (txn.isIncome) inc += txn.amount;
        }
      }
      trend6.add(_MonthSummary(
        label: DateFormat('MMM', 'id_ID').format(DateTime(year, month)),
        expense: exp,
        income: inc,
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Bulanan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareReport(
              context,
              totalIncome: totalIncome,
              totalExpense: totalExpense,
              surplus: surplus,
              top5: top5,
              categoryNames: categoryNames,
              expenseChangePct: expenseChangePct,
            ),
          ),
          GestureDetector(
            onTap: () => _showHelpSheet(context),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: const Center(
                child: Text(
                  '!',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          // Month Selector
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _prevMonth,
                ),
                Text(
                  _monthFmt.format(_selectedMonth),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right,
                    color: _isCurrentMonth
                        ? AppColors.textSecondary.withAlpha(80)
                        : null,
                  ),
                  onPressed: _isCurrentMonth ? null : _nextMonth,
                ),
              ],
            ),
          ),

          // 1. Ringkasan Bulan
          GlassContainer(
            gradient: AppColors.primaryGradient,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _monthFmt.format(_selectedMonth).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ringkasan Bulan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _SummaryItem(
                        label: 'Total Masuk',
                        value: _compact.format(totalIncome),
                        color: AppColors.income),
                    const SizedBox(width: 16),
                    _SummaryItem(
                        label: 'Total Keluar',
                        value: _compact.format(totalExpense),
                        color: AppColors.expense),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      surplus >= 0 ? 'Surplus' : 'Defisit',
                      style: TextStyle(
                        color: surplus >= 0 ? AppColors.income : AppColors.expense,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _currency.format(surplus.abs()),
                      style: TextStyle(
                        color: surplus >= 0 ? AppColors.income : AppColors.expense,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (expenseChangePct != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      expenseChangePct > 0
                          ? '▲ +${(expenseChangePct * 100).toStringAsFixed(0)}% dari bulan lalu'
                          : '▼ ${(expenseChangePct * 100).toStringAsFixed(0)}% dari bulan lalu',
                      style: TextStyle(
                        color: expenseChangePct > 0.05
                            ? AppColors.expense
                            : expenseChangePct < -0.05
                                ? AppColors.income
                                : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 2. Top 5 Kategori Pengeluaran
          if (top5.isNotEmpty) ...[
            _SectionTitle(title: 'TOP PENGELUARAN'),
            GlassContainer(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: top5.asMap().entries.map((e) {
                  final rank = e.key + 1;
                  final entry = e.value;
                  final catName = categoryNames[entry.key] ?? entry.key;
                  final pct = totalExpense > 0
                      ? entry.value / totalExpense
                      : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                gradient: rank == 1
                                    ? AppColors.primaryGradient
                                    : null,
                                color: rank != 1
                                    ? AppColors.darkCard
                                    : null,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '$rank',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: rank == 1
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                catName,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                            Text(
                              _compact.format(entry.value),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(pct * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: pct.clamp(0.0, 1.0),
                            backgroundColor: AppColors.darkCard,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.chartColors[e.key % AppColors.chartColors.length],
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // 3. Statistik Tambahan
          _SectionTitle(title: 'STATISTIK TAMBAHAN'),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              _StatCard(
                icon: Icons.category_outlined,
                label: 'Transaksi Terbanyak',
                value: mostFrequentCat ?? '-',
              ),
              _StatCard(
                icon: Icons.calendar_today_outlined,
                label: 'Hari Paling Boros',
                value: borosDay ?? '-',
              ),
              _StatCard(
                icon: Icons.today_outlined,
                label: 'Rata-rata Harian',
                value: _compact.format(avgDaily),
              ),
              _StatCard(
                icon: Icons.arrow_upward,
                label: 'Transaksi Terbesar',
                value: biggestAmount > 0 ? _compact.format(biggestAmount) : '-',
                subtitle: biggestDesc.isEmpty
                    ? biggestCat
                    : biggestDesc.length > 14
                        ? '${biggestDesc.substring(0, 14)}…'
                        : biggestDesc,
              ),
            ],
          ),

          // 4. Trend 6 Bulan
          _SectionTitle(title: 'TREN 6 BULAN TERAKHIR'),
          GlassContainer(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: trend6.map((m) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Text(
                          _compact.format(m.expense),
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 40,
                          height: 60,
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 40,
                            height: _trendBarHeight(
                                m.expense,
                                trend6
                                    .map((e) => e.expense)
                                    .reduce((a, b) => a > b ? a : b)),
                            decoration: BoxDecoration(
                              gradient: AppColors.expenseGradient,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m.label,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _trendBarHeight(double value, double max) {
    if (max <= 0) return 4;
    return (value / max * 56).clamp(4, 56);
  }

  Future<void> _shareReport(
    BuildContext context, {
    required double totalIncome,
    required double totalExpense,
    required double surplus,
    required List<MapEntry<String, double>> top5,
    required Map<String, String> categoryNames,
    double? expenseChangePct,
  }) async {
    final currency =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final monthStr = DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth);

    final top5Lines = top5.asMap().entries.map((e) {
      final catName = categoryNames[e.value.key] ?? e.value.key;
      return '${e.key + 1}. $catName: ${currency.format(e.value.value)}';
    }).join('\n');

    String vsLastMonth = '';
    if (expenseChangePct != null) {
      final sign = expenseChangePct > 0 ? 'naik' : 'turun';
      vsLastMonth =
          '\n\n📈 vs bulan lalu: $sign ${(expenseChangePct.abs() * 100).toStringAsFixed(0)}%';
    }

    final reportText = '''📊 LAPORAN KEUANGAN - $monthStr
================================
💰 Total Masuk:    ${currency.format(totalIncome)}
💸 Total Keluar:   ${currency.format(totalExpense)}
💵 ${surplus >= 0 ? 'Surplus' : 'Defisit'}: ${currency.format(surplus.abs())}

📌 TOP PENGELUARAN:
$top5Lines$vsLastMonth
================================
Dibuat dengan Money Management App''';

    try {
      await Share.share(reportText);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: reportText));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Laporan disalin ke clipboard')),
        );
      }
    }
  }

  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ReportHelpSheet(),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _MonthSummary {
  final String label;
  final double expense;
  final double income;

  const _MonthSummary(
      {required this.label, required this.expense, required this.income});
}

// ── ReportHelpSheet ───────────────────────────────────────────────────────────

class _ReportHelpSheet extends StatelessWidget {
  const _ReportHelpSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Cara Membaca Laporan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _HelpRow(
            emoji: '📊',
            title: 'Ringkasan Bulan',
            desc: 'Total pemasukan, pengeluaran, dan surplus/defisit bulan ini.',
          ),
          _HelpRow(
            emoji: '📌',
            title: 'Top Pengeluaran',
            desc: 'Kategori yang paling banyak menguras kantong bulan ini.',
          ),
          _HelpRow(
            emoji: '📈',
            title: 'Perbandingan Bulan Lalu',
            desc: 'Menunjukkan apakah pengeluaran naik atau turun dibanding bulan sebelumnya.',
          ),
          _HelpRow(
            emoji: '📤',
            title: 'Tombol Share',
            desc: 'Kirim laporan ke pasangan, orang tua, atau simpan sebagai teks.',
          ),
        ],
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String desc;
  const _HelpRow(
      {required this.emoji, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
