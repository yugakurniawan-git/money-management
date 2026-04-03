import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../theme/app_colors.dart';
import '../../providers/category_provider.dart';
import '../../services/categorizer_service.dart';
import '../../services/firebase_service.dart';
import '../../services/pdf_parser_service.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/animated_number.dart';
import '../../widgets/common/staggered_list_animation.dart';
import '../../widgets/common/gradient_button.dart';
import 'uncategorized_screen.dart';

class ImportPreviewScreen extends ConsumerStatefulWidget {
  final List<TransactionModel> transactions;
  final String fileName;
  final BcaPdfSummary? pdfSummary;

  const ImportPreviewScreen({
    super.key,
    required this.transactions,
    required this.fileName,
    this.pdfSummary,
  });

  @override
  ConsumerState<ImportPreviewScreen> createState() =>
      _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends ConsumerState<ImportPreviewScreen> {
  late List<TransactionModel> _transactions;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _transactions = List.from(widget.transactions);
  }

  Future<void> _categorizeTransactions() async {
    final categories = ref.read(categoriesProvider).value ?? [];
    if (categories.isEmpty) return;

    final categorizer = CategorizerService();
    setState(() {
      _transactions = categorizer.categorizeAll(_transactions, categories);
    });
  }

  Future<void> _saveTransactions() async {
    setState(() => _isSaving = true);

    try {
      final service = FirebaseService();
      final hashToIdMap = await service.getExistingHashToIdMap();
      final existingHashes = hashToIdMap.keys.toSet();

      final newTransactions = <TransactionModel>[];
      final duplicateTransactions = <TransactionModel>[];

      for (final txn in _transactions) {
        if (existingHashes.contains(txn.importHash)) {
          duplicateTransactions.add(txn);
        } else {
          newTransactions.add(txn);
        }
      }

      final duplicateCount = duplicateTransactions.length;

      if (duplicateCount > 0) {
        if (!mounted) return;

        final action = await _showDuplicateDialog(
          duplicateCount: duplicateCount,
          newCount: newTransactions.length,
          totalCount: _transactions.length,
        );

        if (action == null) {
          setState(() => _isSaving = false);
          return;
        }

        if (action == _DuplicateAction.skipAll && newTransactions.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Tidak ada transaksi baru. $duplicateCount duplikat diskip.'),
                backgroundColor: AppColors.expenseLight,
              ),
            );
          }
          setState(() => _isSaving = false);
          return;
        }

        if (action == _DuplicateAction.replaceAll) {
          final idsToDelete = <String>[];
          for (final txn in duplicateTransactions) {
            final existingId = hashToIdMap[txn.importHash];
            if (existingId != null) {
              idsToDelete.add(existingId);
            }
          }

          await service.replaceTransactions(idsToDelete, _transactions);

          if (mounted) {
            await _checkUncategorized(_transactions, _transactions.length);
          }
          return;
        }

        if (newTransactions.isNotEmpty) {
          await service.addTransactions(newTransactions);
        }

        if (mounted) {
          await _checkUncategorized(newTransactions, newTransactions.length,
              skipped: duplicateCount);
        }
        return;
      }

      await service.addTransactions(newTransactions);

      if (mounted) {
        await _checkUncategorized(newTransactions, newTransactions.length);
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

  /// Setelah simpan: cek transaksi tanpa kategori, tawarkan untuk update
  Future<void> _checkUncategorized(
    List<TransactionModel> saved,
    int totalSaved, {
    int skipped = 0,
  }) async {
    final uncategorized =
        saved.where((t) => t.isExpense && t.categoryId.isEmpty).toList();

    final baseMsg = '$totalSaved transaksi berhasil diimport'
        '${skipped > 0 ? ' ($skipped duplikat diskip)' : ''}';

    if (uncategorized.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(baseMsg),
          backgroundColor: AppColors.income,
        ));
        Navigator.of(context).pop();
      }
      return;
    }

    // Ada transaksi tanpa kategori — tampilkan dialog pilihan
    if (!mounted) return;
    final goUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.darkCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(26),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.label_off_outlined,
                    color: Colors.amber, size: 30),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ada Transaksi Tanpa Kategori',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              GlassContainer(
                padding: const EdgeInsets.all(14),
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    _dialogInfoRow(
                      Icons.check_circle_outline,
                      'Berhasil diimport',
                      '$totalSaved transaksi',
                      AppColors.income,
                    ),
                    const SizedBox(height: 8),
                    _dialogInfoRow(
                      Icons.label_off_outlined,
                      'Belum berkategori',
                      '${uncategorized.length} transaksi',
                      Colors.amber,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${uncategorized.length} transaksi pengeluaran tidak menemukan kategori yang cocok. Mau diatur sekarang?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  text: 'Update Kategori Sekarang',
                  icon: Icons.edit_outlined,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                        color: AppColors.primary.withAlpha(100)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(Icons.skip_next,
                      color: AppColors.primary, size: 20),
                  label: Text(
                    'Skip, Atur Nanti',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;

    if (goUpdate == true) {
      // Navigasi ke halaman kategorisasi manual
      await Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (_, anim, __) =>
            UncategorizedScreen(transactions: uncategorized),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween(
                  begin: const Offset(1.0, 0), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ));
    } else {
      // Skip — kembali ke halaman sebelumnya
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '$baseMsg · ${uncategorized.length} belum berkategori'),
          backgroundColor: AppColors.income,
        ));
        Navigator.of(context).pop();
      }
    }
  }

  Future<_DuplicateAction?> _showDuplicateDialog({
    required int duplicateCount,
    required int newCount,
    required int totalCount,
  }) async {
    return showDialog<_DuplicateAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(26),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Data Duplikat Ditemukan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              GlassContainer(
                padding: const EdgeInsets.all(14),
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    _dialogInfoRow(Icons.insert_drive_file_outlined,
                        'Total dari file', '$totalCount transaksi', AppColors.primary),
                    const SizedBox(height: 8),
                    _dialogInfoRow(Icons.fiber_new, 'Transaksi baru',
                        '$newCount transaksi', AppColors.income),
                    const SizedBox(height: 8),
                    _dialogInfoRow(Icons.copy_rounded, 'Sudah ada (duplikat)',
                        '$duplicateCount transaksi', Colors.amber),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Apa yang ingin kamu lakukan dengan\ndata duplikat?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  text: 'Timpa Semua (Replace)',
                  onPressed: () =>
                      Navigator.pop(context, _DuplicateAction.replaceAll),
                  icon: Icons.sync,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, _DuplicateAction.skipAll),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppColors.primary.withAlpha(100)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(Icons.skip_next, color: AppColors.primary, size: 20),
                  label: Text(
                    newCount > 0
                        ? 'Simpan Baru, Skip Duplikat'
                        : 'Skip Semua Duplikat',
                    style: TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Batal',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogInfoRow(
      IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(value,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryNames = ref.watch(categoryNameMapProvider);
    final currencyFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_transactions.every((t) => t.categoryId.isEmpty)) {
        _categorizeTransactions();
      }
    });

    final totalIncome = _transactions
        .where((t) => t.isIncome)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final totalExpense = _transactions
        .where((t) => t.isExpense)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final incomeCount = _transactions.where((t) => t.isIncome).length;
    final expenseCount = _transactions.where((t) => t.isExpense).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Import'),
      ),
      body: Column(
        children: [
          // BCA Summary Card (if available from PDF)
          if (widget.pdfSummary != null) _buildSummaryCard(widget.pdfSummary!),

          // File info header
          GlassContainer(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.description,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(widget.fileName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(26),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${_transactions.length} transaksi',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.arrow_downward,
                              color: AppColors.income, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedNumber(
                                  value: totalIncome,
                                  style: TextStyle(
                                      color: AppColors.income,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                                Text('$incomeCount masuk',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.arrow_upward,
                              color: AppColors.expense, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedNumber(
                                  value: totalExpense,
                                  style: TextStyle(
                                      color: AppColors.expense,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                                Text('$expenseCount keluar',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10)),
                              ],
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

          // Transaction list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                final txn = _transactions[index];
                final categoryName =
                    categoryNames[txn.categoryId] ?? 'Belum dikategorikan';
                final isIncome = txn.isIncome;

                return StaggeredListItem(
                  index: index,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard.withAlpha(140),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: isIncome
                                ? AppColors.incomeGradient
                                : AppColors.expenseGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isIncome
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                txn.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${dateFormat.format(txn.transactionDate)} • $categoryName',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ShaderMask(
                          shaderCallback: (bounds) => (isIncome
                                  ? AppColors.incomeGradient
                                  : AppColors.expenseGradient)
                              .createShader(bounds),
                          child: Text(
                            '${txn.isExpense ? '-' : '+'}${currencyFormat.format(txn.amount)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Save button
          Padding(
            padding: const EdgeInsets.all(16),
            child: GradientButton(
              text: _isSaving ? 'Menyimpan...' : 'Simpan Transaksi',
              isLoading: _isSaving,
              onPressed: _saveTransactions,
              icon: Icons.save,
            ),
          ),
        ],
      ),
    );
  }

  /// Build BCA statement summary card
  Widget _buildSummaryCard(BcaPdfSummary summary) {
    final currencyFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return GlassContainer(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Rekening Koran BCA
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF003399), Color(0xFF0066CC)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('BCA',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rekening Koran BCA',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    if (summary.periode.isNotEmpty || summary.noRekening.isNotEmpty)
                      Text(
                        '${summary.periode}${summary.noRekening.isNotEmpty ? ' • ${summary.noRekening}' : ''}',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Saldo Awal & Akhir
          Row(
            children: [
              Expanded(
                child: _summaryItem(
                  'Saldo Awal',
                  currencyFormat.format(summary.saldoAwal),
                  AppColors.textSecondary,
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: AppColors.textSecondary.withAlpha(50),
              ),
              Expanded(
                child: _summaryItem(
                  'Saldo Akhir',
                  currencyFormat.format(summary.saldoAkhir),
                  AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mutasi CR & DB
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.darkBg.withAlpha(120),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.income,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mutasi CR',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary)),
                            Text(
                              currencyFormat.format(summary.mutasiCr),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.income),
                            ),
                            Text('${summary.countCr} transaksi',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.expense,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mutasi DB',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary)),
                            Text(
                              currencyFormat.format(summary.mutasiDb),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.expense),
                            ),
                            Text('${summary.countDb} transaksi',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }
}

enum _DuplicateAction { replaceAll, skipAll }
