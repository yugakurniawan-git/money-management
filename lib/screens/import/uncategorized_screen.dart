import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../theme/app_colors.dart';
import '../../providers/category_provider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/gradient_button.dart';

class UncategorizedScreen extends ConsumerStatefulWidget {
  final List<TransactionModel> transactions;

  const UncategorizedScreen({super.key, required this.transactions});

  @override
  ConsumerState<UncategorizedScreen> createState() =>
      _UncategorizedScreenState();
}

class _UncategorizedScreenState extends ConsumerState<UncategorizedScreen> {
  late List<TransactionModel> _transactions;
  bool _isSaving = false;
  int _savedCount = 0;

  final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _date = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _transactions = List.from(widget.transactions);
  }

  Future<void> _pickCategory(int index) async {
    final categories = ref.read(categoriesProvider).value ?? [];
    if (categories.isEmpty) return;

    final selected = await showModalBottomSheet<CategoryModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryPickerSheet(categories: categories),
    );

    if (selected == null) return;

    setState(() {
      _transactions[index] =
          _transactions[index].copyWith(categoryId: selected.id);
    });
  }

  Future<void> _saveAll() async {
    final categorized =
        _transactions.where((t) => t.categoryId.isNotEmpty).toList();
    if (categorized.isEmpty) {
      Navigator.of(context)
        ..pop() // pop uncategorized screen
        ..pop(); // pop preview screen
      return;
    }

    setState(() => _isSaving = true);
    try {
      final service = FirebaseService();
      for (final txn in categorized) {
        await service.updateTransaction(txn);
      }
      setState(() => _savedCount = categorized.length);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '$_savedCount transaksi berhasil diperbarui kategorinya'),
            backgroundColor: AppColors.income,
          ),
        );
        // Pop both uncategorized screen + preview screen
        Navigator.of(context)
          ..pop()
          ..pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryNames = ref.watch(categoryNameMapProvider);
    final categorized = _transactions.where((t) => t.categoryId.isNotEmpty).length;
    final total = _transactions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Atur Kategori'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(38),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$categorized / $total dikategorikan',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? categorized / total : 0,
                    backgroundColor: AppColors.darkCard,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap transaksi untuk memilih kategori',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // Transaction list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: _transactions.length,
              itemBuilder: (context, i) {
                final txn = _transactions[i];
                final hasCat = txn.categoryId.isNotEmpty;
                final catName =
                    hasCat ? (categoryNames[txn.categoryId] ?? '?') : null;

                return GestureDetector(
                  onTap: () => _pickCategory(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: hasCat
                          ? AppColors.primary.withAlpha(18)
                          : AppColors.darkCard.withAlpha(180),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hasCat
                            ? AppColors.primary.withAlpha(80)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Type icon
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: txn.isIncome
                                ? AppColors.incomeGradient
                                : AppColors.expenseGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            txn.isIncome
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Description + date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                txn.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _date.format(txn.transactionDate),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Right side: amount + category badge
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${txn.isExpense ? '-' : '+'}${_currency.format(txn.amount)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: txn.isIncome
                                    ? AppColors.income
                                    : AppColors.expense,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: hasCat
                                    ? AppColors.primaryGradient
                                    : null,
                                color: hasCat
                                    ? null
                                    : AppColors.textSecondary.withAlpha(40),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasCat
                                        ? Icons.check
                                        : Icons.add,
                                    size: 10,
                                    color: hasCat
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    hasCat
                                        ? catName!
                                        : 'Pilih Kategori',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: hasCat
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              children: [
                GradientButton(
                  text: _isSaving
                      ? 'Menyimpan...'
                      : 'Simpan ($categorized dikategorikan)',
                  isLoading: _isSaving,
                  onPressed: categorized > 0 ? _saveAll : null,
                  icon: Icons.save,
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.of(context)
                      ..pop()
                      ..pop();
                  },
                  child: Text(
                    'Lewati, atur nanti',
                    style: TextStyle(color: AppColors.textSecondary),
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

// ── Category Picker Bottom Sheet ─────────────────────────────────────────────

class _CategoryPickerSheet extends StatefulWidget {
  final List<CategoryModel> categories;
  const _CategoryPickerSheet({required this.categories});

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.categories
        .where((c) =>
            c.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pilih Kategori',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                GlassContainer(
                  padding: EdgeInsets.zero,
                  borderRadius: 12,
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Cari kategori...',
                      prefixIcon: Icon(Icons.search,
                          color: AppColors.textSecondary, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final cat = filtered[i];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: cat.color.withAlpha(50),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(cat.icon,
                          style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                  title: Text(cat.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14)),
                  onTap: () => Navigator.pop(context, cat),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
