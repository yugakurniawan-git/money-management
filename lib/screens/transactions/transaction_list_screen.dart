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
                  prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),

          // Active filters
          if (_filterType != null || _filterCategoryId != null)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            ),

          // Transaction list
          Expanded(
            child: transactionsAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (transactions) {
                final filtered = _applyFilters(transactions);

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'Tidak ada transaksi ditemukan',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                final grouped = _groupByDate(filtered);
                int itemIndex = 0;

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final entry = grouped.entries.elementAt(index);
                    final widgets = <Widget>[
                      StaggeredListItem(
                        index: itemIndex++,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
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
                      ),
                      ...entry.value.map((txn) => StaggeredListItem(
                            index: itemIndex++,
                            child: TransactionTile(
                              transaction: txn,
                              categoryName:
                                  categoryNames[txn.categoryId] ?? 'Lainnya',
                              onTap: () => Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder: (_, anim, __) =>
                                      TransactionDetailScreen(
                                          transaction: txn),
                                  transitionsBuilder:
                                      (_, anim, __, child) {
                                    return FadeTransition(
                                      opacity: anim,
                                      child: SlideTransition(
                                        position: Tween(
                                          begin: const Offset(0.05, 0),
                                          end: Offset.zero,
                                        ).animate(CurvedAnimation(
                                          parent: anim,
                                          curve: Curves.easeOutCubic,
                                        )),
                                        child: child,
                                      ),
                                    );
                                  },
                                  transitionDuration:
                                      const Duration(milliseconds: 350),
                                ),
                              ),
                            ),
                          )),
                    ];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widgets,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              child: const Icon(Icons.close, size: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  List<TransactionModel> _applyFilters(List<TransactionModel> transactions) {
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
      if (_filterCategoryId != null && txn.categoryId != _filterCategoryId) {
        return false;
      }
      return true;
    }).toList();
  }

  Map<String, List<TransactionModel>> _groupByDate(
      List<TransactionModel> transactions) {
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');
    final grouped = <String, List<TransactionModel>>{};
    for (final txn in transactions) {
      final key = dateFormat.format(txn.transactionDate);
      grouped.putIfAbsent(key, () => []).add(txn);
    }
    return grouped;
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

  Widget _buildChoiceChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
