import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../models/transaction.dart';
import '../../widgets/common/transaction_tile.dart';
import '../../widgets/common/staggered_list_animation.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/gradient_button.dart';
import 'transaction_detail_screen.dart';

enum _DatePreset { today, week, month, year, custom }

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState
    extends ConsumerState<TransactionListScreen> {
  String _searchQuery = '';
  String? _filterType;
  String? _filterCategoryId;
  _DatePreset? _datePreset;
  DateTime? _startDate;
  DateTime? _endDate;

  static const _presets = [
    (_DatePreset.today, 'Hari Ini'),
    (_DatePreset.week, 'Minggu Ini'),
    (_DatePreset.month, 'Bulan Ini'),
    (_DatePreset.year, 'Tahun Ini'),
    (_DatePreset.custom, 'Pilih Tanggal'),
  ];

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoryNames = ref.watch(categoryNameMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.filter_list, size: 20),
            ),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: GlassContainer(
              padding: EdgeInsets.zero,
              borderRadius: 14,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Cari transaksi...',
                  prefixIcon:
                      Icon(Icons.search, color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),

          // Date filter chips
          _buildDateFilterRow(),

          // Active type/category filter chips
          if (_filterType != null || _filterCategoryId != null)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  if (_filterType != null)
                    _filterChip(
                      _filterType == 'credit' ? 'Pemasukan' : 'Pengeluaran',
                      () => setState(() => _filterType = null),
                    ),
                  if (_filterCategoryId != null)
                    _filterChip(
                      categoryNames[_filterCategoryId] ?? 'Kategori',
                      () => setState(() => _filterCategoryId = null),
                    ),
                ],
              ),
            ),

          // Transaction list + analysis
          Expanded(
            child: transactionsAsync.when(
              loading: () => Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primary)),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (transactions) {
                final dateFiltered = _applyDateFilter(transactions);
                final filtered = _applyTypeAndSearch(dateFiltered);
                final grouped = _groupByDate(filtered);

                return CustomScrollView(
                  slivers: [
                    // Analisis pengeluaran (hanya saat ada filter tanggal)
                    if (_datePreset != null &&
                        (_filterType == null || _filterType == 'debit'))
                      SliverToBoxAdapter(
                        child: _buildSpendingAnalysis(
                            dateFiltered, categoryNames),
                      ),

                    if (filtered.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'Tidak ada transaksi ditemukan',
                            style:
                                TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final entry =
                                  grouped.entries.elementAt(i);
                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        0, 12, 0, 8),
                                    child: Text(
                                      entry.key,
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  ...entry.value.map((txn) =>
                                      StaggeredListItem(
                                        index: 0,
                                        child: TransactionTile(
                                          transaction: txn,
                                          categoryName:
                                              categoryNames[txn.categoryId] ??
                                                  'Lainnya',
                                          onTap: () =>
                                              _pushDetail(context, txn),
                                        ),
                                      )),
                                ],
                              );
                            },
                            childCount: grouped.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Date filter row ──────────────────────────────────────────────────────

  Widget _buildDateFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          _dateChip('Semua', _datePreset == null, () {
            setState(() {
              _datePreset = null;
              _startDate = null;
              _endDate = null;
            });
          }),
          ..._presets.map((p) {
            final selected = _datePreset == p.$1;
            String label = p.$2;
            if (p.$1 == _DatePreset.custom &&
                selected &&
                _startDate != null &&
                _endDate != null) {
              label =
                  '${DateFormat('dd/MM').format(_startDate!)} – ${DateFormat('dd/MM').format(_endDate!)}';
            }
            return _dateChip(
              label,
              selected,
              () => _selectPreset(p.$1),
              icon: p.$1 == _DatePreset.custom
                  ? Icons.calendar_today
                  : null,
            );
          }),
        ],
      ),
    );
  }

  Widget _dateChip(String label, bool selected, VoidCallback onTap,
      {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.primaryGradient : null,
            color: selected ? null : AppColors.darkCard,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 12,
                    color: selected
                        ? Colors.white
                        : AppColors.textSecondary),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectPreset(_DatePreset preset) async {
    final now = DateTime.now();
    DateTime start, end;

    if (preset == _DatePreset.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        initialDateRange: _startDate != null && _endDate != null
            ? DateTimeRange(start: _startDate!, end: _endDate!)
            : DateTimeRange(
                start: now.subtract(const Duration(days: 30)),
                end: now,
              ),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.darkCard,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        ),
      );
      if (picked == null) return;
      start = DateTime(
          picked.start.year, picked.start.month, picked.start.day);
      end = DateTime(
          picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
    } else {
      switch (preset) {
        case _DatePreset.today:
          start = DateTime(now.year, now.month, now.day);
          end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        case _DatePreset.week:
          final diff = now.weekday - 1;
          start = DateTime(now.year, now.month, now.day - diff);
          end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        case _DatePreset.month:
          start = DateTime(now.year, now.month, 1);
          end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        case _DatePreset.year:
          start = DateTime(now.year, 1, 1);
          end = DateTime(now.year, 12, 31, 23, 59, 59);
        default:
          return;
      }
    }

    setState(() {
      _datePreset = preset;
      _startDate = start;
      _endDate = end;
    });
  }

  // ── Spending analysis ─────────────────────────────────────────────────────

  Widget _buildSpendingAnalysis(List<TransactionModel> transactions,
      Map<String, String> categoryNames) {
    final expenses =
        transactions.where((t) => t.isExpense).toList();
    if (expenses.isEmpty) return const SizedBox.shrink();

    final breakdown = <String, double>{};
    final catTxns = <String, List<TransactionModel>>{};
    for (final txn in expenses) {
      final key = txn.categoryId;
      breakdown[key] = (breakdown[key] ?? 0) + txn.amount;
      catTxns.putIfAbsent(key, () => []).add(txn);
    }

    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = breakdown.values.fold(0.0, (a, b) => a + b);
    final currency = NumberFormat.currency(
        locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return GlassContainer(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (b) =>
                    AppColors.primaryGradient.createShader(b),
                child: const Icon(Icons.pie_chart_outline,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              const Text('Analisis Pengeluaran',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              Text(
                currency.format(total),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...sorted.take(8).map((entry) {
            final catName =
                categoryNames[entry.key] ?? 'Lainnya';
            final pct = total > 0 ? entry.value / total : 0.0;
            return GestureDetector(
              onTap: () => _showCategoryDetail(
                catName,
                catTxns[entry.key] ?? [],
                categoryNames,
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(catName,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),
                        Text(
                          currency.format(entry.value),
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primary.withAlpha(38),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${(pct * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            size: 16,
                            color: AppColors.textSecondary),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor:
                            AppColors.darkCard,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (sorted.length > 8)
            Center(
              child: Text(
                '+ ${sorted.length - 8} kategori lainnya',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  void _showCategoryDetail(
    String categoryName,
    List<TransactionModel> transactions,
    Map<String, String> categoryNames,
  ) {
    final sorted = [...transactions]
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final currency = NumberFormat.currency(
        locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final total = transactions.fold(0.0, (a, t) => a + t.amount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (ctx, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withAlpha(77),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(categoryName,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            '${transactions.length} transaksi · diurutkan terbesar',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Total',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                        Text(
                          currency.format(total),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(
                  height: 1,
                  color: AppColors.glassBorderDark),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: sorted.length,
                  itemBuilder: (context, i) {
                    final txn = sorted[i];
                    return TransactionTile(
                      transaction: txn,
                      categoryName:
                          categoryNames[txn.categoryId] ?? categoryName,
                      onTap: () {
                        Navigator.pop(context);
                        _pushDetail(context, txn);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _pushDetail(BuildContext context, TransactionModel txn) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) =>
          TransactionDetailScreen(transaction: txn),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(
                  begin: const Offset(0.05, 0), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  List<TransactionModel> _applyDateFilter(
      List<TransactionModel> transactions) {
    if (_startDate == null || _endDate == null) return transactions;
    return transactions
        .where((t) =>
            !t.transactionDate.isBefore(_startDate!) &&
            !t.transactionDate.isAfter(_endDate!))
        .toList();
  }

  List<TransactionModel> _applyTypeAndSearch(
      List<TransactionModel> transactions) {
    return transactions.where((txn) {
      if (_searchQuery.isNotEmpty &&
          !txn.description
              .toLowerCase()
              .contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_filterType != null && txn.transactionType != _filterType) {
        return false;
      }
      if (_filterCategoryId != null &&
          txn.categoryId != _filterCategoryId) {
        return false;
      }
      return true;
    }).toList();
  }

  Map<String, List<TransactionModel>> _groupByDate(
      List<TransactionModel> transactions) {
    final fmt = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');
    final grouped = <String, List<TransactionModel>>{};
    for (final txn in transactions) {
      final key = fmt.format(txn.transactionDate);
      grouped.putIfAbsent(key, () => []).add(txn);
    }
    return grouped;
  }

  Widget _filterChip(String label, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemove,
              child:
                  const Icon(Icons.close, size: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
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
            Text('Filter',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            Text('TIPE TRANSAKSI',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                )),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildChoiceChip('Semua', _filterType == null,
                    () => setState(() => _filterType = null)),
                const SizedBox(width: 8),
                _buildChoiceChip('Pemasukan', _filterType == 'credit',
                    () => setState(() => _filterType = 'credit')),
                const SizedBox(width: 8),
                _buildChoiceChip('Pengeluaran', _filterType == 'debit',
                    () => setState(() => _filterType = 'debit')),
              ],
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Terapkan',
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip(
      String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : AppColors.darkCard,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
