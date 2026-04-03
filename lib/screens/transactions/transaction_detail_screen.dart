import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../theme/app_colors.dart';
import '../../providers/category_provider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/animated_number.dart';
import '../../widgets/common/staggered_list_animation.dart';
import '../../widgets/common/gradient_button.dart';

class TransactionDetailScreen extends ConsumerStatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  late TransactionModel _transaction;
  final _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
    _noteController.text = _transaction.note;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final updated = _transaction.copyWith(note: _noteController.text);
      await FirebaseService().updateTransaction(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tersimpan')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? [];
    final currencyFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');
    final isIncome = _transaction.isIncome;
    final gradient = isIncome ? AppColors.incomeGradient : AppColors.expenseGradient;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Transaksi'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Amount card with gradient
          StaggeredListItem(
            index: 0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (isIncome ? AppColors.income : AppColors.expense)
                        .withAlpha(60),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    builder: (_, value, child) => Transform.scale(
                      scale: value,
                      child: child,
                    ),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(51),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedNumber(
                    value: _transaction.amount,
                    prefix: _transaction.isExpense ? '-Rp ' : '+Rp ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dateFormat.format(_transaction.transactionDate),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Details
          StaggeredListItem(
            index: 1,
            child: GlassContainer(
              child: Column(
                children: [
                  _detailRow('Deskripsi', _transaction.description),
                  _divider(),
                  _detailRow('Saldo Setelah',
                      currencyFormat.format(_transaction.balanceAfter)),
                  _divider(),
                  _detailRow('Tipe',
                      isIncome ? 'Pemasukan' : 'Pengeluaran'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Category picker
          StaggeredListItem(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KATEGORI',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    )),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _transaction.categoryId.isEmpty
                      ? null
                      : _transaction.categoryId,
                  hint: const Text('Pilih kategori'),
                  items: categories
                      .map((cat) => DropdownMenuItem(
                            value: cat.id,
                            child: Text(cat.name),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _transaction =
                            _transaction.copyWith(categoryId: value);
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Note
          StaggeredListItem(
            index: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CATATAN',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    hintText: 'Tambah catatan...',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Save button
          StaggeredListItem(
            index: 4,
            child: GradientButton(
              text: 'Simpan',
              isLoading: _isSaving,
              onPressed: _saveChanges,
              icon: Icons.check,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
        color: AppColors.glassBorderDark,
        height: 1,
      );
}
