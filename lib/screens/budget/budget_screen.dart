import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/budget.dart';
import '../../models/category.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/gradient_button.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  late DateTime _selectedMonth;
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _monthFmt = DateFormat('MMMM yyyy', 'id_ID');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _selectedMonth = next);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  Future<void> _showAddEditSheet({BudgetStatus? existing}) async {
    final categories = ref.read(categoriesProvider).value ?? [];
    final budgets = ref.read(budgetsProvider).value ?? [];
    // Filter out already-budgeted categories when adding new
    final usedIds = existing != null
        ? budgets.where((b) => b.id != existing.budget.id).map((b) => b.categoryId).toSet()
        : budgets.map((b) => b.categoryId).toSet();

    final expenseCategories = categories.where((c) => c.type == 'expense').toList();
    final availableCategories = existing != null
        ? expenseCategories
        : expenseCategories.where((c) => !usedIds.contains(c.id)).toList();

    if (availableCategories.isEmpty && existing == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua kategori pengeluaran sudah memiliki budget'),
            backgroundColor: Color(0xFFFF9800),
          ),
        );
      }
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditBudgetSheet(
        existingStatus: existing,
        availableCategories: availableCategories,
        allCategories: expenseCategories,
        selectedMonth: _selectedMonth,
      ),
    );
  }

  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BudgetHelpSheet(),
    );
  }

  Future<void> _deleteBudget(BudgetStatus status) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Budget'),
        content: Text(
          'Hapus budget untuk kategori ini?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseService().deleteBudget(status.budget.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = ref.watch(budgetStatusProvider(_selectedMonth));
    final summary = ref.watch(budgetSummaryProvider(_selectedMonth));
    final categoryMap = ref.watch(categoryMapProvider);

    final overBudget = statuses.where((s) => s.isOver).toList();
    final warningBudget = statuses.where((s) => s.isWarning).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 0,
            title: const Text(
              'Budget',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
            actions: [
              IconButton(
                icon: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(30),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.primary.withAlpha(100), width: 1.5),
                  ),
                  child: const Center(
                    child: Text(
                      '!',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                tooltip: 'Cara kerja fitur Budget',
                onPressed: () => _showHelpSheet(context),
              ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: _MonthSelector(
                month: _selectedMonth,
                monthFmt: _monthFmt,
                onPrev: _prevMonth,
                onNext: _isCurrentMonth ? null : _nextMonth,
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Alert banners
                if (overBudget.isNotEmpty)
                  _AlertBanner(
                    icon: Icons.warning_rounded,
                    color: const Color(0xFFE53935),
                    message:
                        '${overBudget.length} kategori melebihi budget bulan ini',
                  ),
                if (warningBudget.isNotEmpty)
                  _AlertBanner(
                    icon: Icons.info_outline,
                    color: const Color(0xFFFF9800),
                    message:
                        '${warningBudget.length} kategori hampir mencapai batas budget',
                  ),

                // Summary card
                if (statuses.isNotEmpty) ...[
                  _BudgetSummaryCard(summary: summary, currency: _currency),
                  const SizedBox(height: 20),
                ],

                // Section header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BUDGET PER KATEGORI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${statuses.length} kategori',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Budget list
                if (statuses.isEmpty)
                  _EmptyBudget(onAdd: () => _showAddEditSheet())
                else
                  ...statuses.map((status) {
                    final cat = categoryMap[status.budget.categoryId];
                    return _BudgetItem(
                      status: status,
                      categoryName: cat?.name ?? 'Kategori',
                      categoryIcon: cat?.icon ?? '📁',
                      categoryColor: cat?.color ?? AppColors.primary,
                      currency: _currency,
                      onEdit: () => _showAddEditSheet(existing: status),
                      onDelete: () => _deleteBudget(status),
                    );
                  }),
              ]),
            ),
          ),
        ],
      ),

      // FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditSheet(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Tambah Budget',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── Month Selector ────────────────────────────────────────────────────────────

class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final DateFormat monthFmt;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  const _MonthSelector({
    required this.month,
    required this.monthFmt,
    required this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
            iconSize: 22,
            color: AppColors.primary,
          ),
          Text(
            monthFmt.format(month),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: onNext != null ? AppColors.primary : AppColors.textSecondary,
            ),
            onPressed: onNext,
            iconSize: 22,
          ),
        ],
      ),
    );
  }
}

// ── Alert Banner ──────────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _AlertBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Budget Summary Card ───────────────────────────────────────────────────────

class _BudgetSummaryCard extends StatelessWidget {
  final BudgetSummary summary;
  final NumberFormat currency;

  const _BudgetSummaryCard({required this.summary, required this.currency});

  @override
  Widget build(BuildContext context) {
    final pct = summary.percentage.clamp(0.0, 1.0);
    final overallColor = summary.overCount > 0
        ? const Color(0xFFE53935)
        : summary.warningCount > 0
            ? const Color(0xFFFF9800)
            : const Color(0xFF43A047);

    return GlassContainer(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Total Budget Bulan Ini',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (summary.overCount > 0)
                _StatusChip(
                  label: '${summary.overCount} Over',
                  color: const Color(0xFFE53935),
                )
              else if (summary.warningCount > 0)
                _StatusChip(
                  label: '${summary.warningCount} Warning',
                  color: const Color(0xFFFF9800),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currency.format(summary.totalSpent),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '/ ${currency.format(summary.totalLimit)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.darkCard,
              valueColor: AlwaysStoppedAnimation<Color>(overallColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(pct * 100).toStringAsFixed(0)}% terpakai',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                'Sisa ${currency.format(summary.remaining)}',
                style: TextStyle(
                  fontSize: 12,
                  color: summary.remaining >= 0
                      ? const Color(0xFF43A047)
                      : const Color(0xFFE53935),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Budget Item ───────────────────────────────────────────────────────────────

class _BudgetItem extends StatelessWidget {
  final BudgetStatus status;
  final String categoryName;
  final String categoryIcon;
  final Color categoryColor;
  final NumberFormat currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BudgetItem({
    required this.status,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final pct = status.percentage.clamp(0.0, 1.0);

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              // Category icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: categoryColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(categoryIcon, style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),

              // Name + status label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: status.statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          status.statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: status.statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFE53935)),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.darkCard,
              valueColor: AlwaysStoppedAnimation<Color>(status.statusColor),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 8),

          // Amounts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Terpakai: ${currency.format(status.spent)}',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                'Limit: ${currency.format(status.limit)}',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),

          // Remaining
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              status.isOver
                  ? 'Melebihi ${currency.format(status.spent - status.limit)}'
                  : 'Sisa ${currency.format(status.remaining)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: status.isOver
                    ? const Color(0xFFE53935)
                    : const Color(0xFF43A047),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyBudget extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyBudget({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.account_balance_wallet,
                color: Colors.white, size: 30),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada budget',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambahkan budget untuk setiap kategori\npengeluaran agar keuangan lebih terkontrol',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          GradientButton(
            text: 'Tambah Budget Pertama',
            onPressed: onAdd,
            icon: Icons.add,
            height: 46,
          ),
        ],
      ),
    );
  }
}

// ── Budget Help Sheet ─────────────────────────────────────────────────────────

class _BudgetHelpSheet extends StatelessWidget {
  const _BudgetHelpSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withAlpha(77),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          '!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cara Kerja Fitur Budget',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Panduan lengkap untuk kamu & pasangan',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 24, indent: 20, endIndent: 20),

              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: const [
                    _HelpSection(
                      emoji: '💡',
                      title: 'Apa itu Budget?',
                      body:
                          'Budget adalah batas maksimal uang yang boleh kamu keluarkan untuk satu kategori dalam sebulan.\n\n'
                          'Contoh: kamu atur budget Rp 500.000 untuk kategori "Makan & Minum". Setiap kali ada transaksi pengeluaran di kategori itu, aplikasi otomatis menghitung sudah berapa yang terpakai.',
                    ),
                    _HelpSection(
                      emoji: '➕',
                      title: 'Cara Menambah Budget',
                      body:
                          '1. Tap tombol "+ Tambah Budget" di bagian bawah layar.\n'
                          '2. Pilih kategori pengeluaran (misal: Belanja, Transportasi, dll).\n'
                          '3. Isi jumlah batas bulanan dalam Rupiah.\n'
                          '4. Tap "Simpan Budget".\n\n'
                          'Setiap kategori hanya bisa punya satu budget. Kategori yang sudah diatur tidak akan muncul lagi di daftar pilihan.',
                    ),
                    _HelpSection(
                      emoji: '✏️',
                      title: 'Cara Mengubah atau Menghapus Budget',
                      body:
                          'Di setiap baris budget, ada dua tombol di sisi kanan:\n\n'
                          '• Ikon pensil (✏️) → untuk mengubah jumlah batas budget.\n'
                          '• Ikon tempat sampah (🗑️) → untuk menghapus budget kategori tersebut.\n\n'
                          'Menghapus budget tidak menghapus transaksimu, hanya menghilangkan batas yang kamu atur.',
                    ),
                    _HelpSection(
                      emoji: '🎨',
                      title: 'Arti Warna pada Progress Bar',
                      isColorGuide: true,
                    ),
                    _HelpSection(
                      emoji: '📅',
                      title: 'Filter Bulan',
                      body:
                          'Gunakan tombol panah kiri/kanan di bagian atas untuk melihat budget bulan-bulan sebelumnya.\n\n'
                          'Data pengeluaran otomatis menyesuaikan dengan bulan yang dipilih, jadi kamu bisa mengecek apakah bulan lalu sudah sesuai rencana atau belum.',
                    ),
                    _HelpSection(
                      emoji: '⚠️',
                      title: 'Notifikasi Banner Merah & Orange',
                      body:
                          '• Banner MERAH muncul jika ada kategori yang sudah melebihi batas budget.\n'
                          '• Banner ORANGE muncul jika ada kategori yang sudah terpakai 80% atau lebih.\n\n'
                          'Ini membantu kamu langsung tahu kondisi keuangan bulan ini tanpa harus mengecek satu per satu.',
                    ),
                    _HelpSection(
                      emoji: '🔄',
                      title: 'Budget Berlaku Setiap Bulan',
                      body:
                          'Budget yang kamu atur berlaku permanen — artinya limit yang sama otomatis dipakai setiap bulan.\n\n'
                          'Kamu tidak perlu mengatur ulang setiap bulan. Cukup ubah jika memang ingin menyesuaikan anggaran.',
                    ),
                    _HelpSection(
                      emoji: '📊',
                      title: 'Budget di Dashboard',
                      body:
                          'Ringkasan budget juga muncul di halaman Dashboard, tepat di bawah kartu saldo.\n\n'
                          'Di sana kamu bisa lihat total pengeluaran vs total budget bulan ini, plus 3 kategori yang paling mendekati batasnya.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HelpSection extends StatelessWidget {
  final String emoji;
  final String title;
  final String? body;
  final bool isColorGuide;

  const _HelpSection({
    required this.emoji,
    required this.title,
    this.body,
    this.isColorGuide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (isColorGuide) ...[
            _ColorRow(
              color: const Color(0xFF43A047),
              label: 'Hijau — Aman',
              desc: 'Pengeluaran masih di bawah 60% dari budget.',
            ),
            _ColorRow(
              color: const Color(0xFFFFB300),
              label: 'Kuning — Waspada',
              desc: 'Sudah terpakai 60–79%. Mulai hati-hati.',
            ),
            _ColorRow(
              color: const Color(0xFFFF9800),
              label: 'Orange — Hampir Habis',
              desc: 'Sudah terpakai 80–99%. Hampir mencapai batas.',
            ),
            _ColorRow(
              color: const Color(0xFFE53935),
              label: 'Merah — Over Budget',
              desc: 'Pengeluaran sudah melebihi batas yang ditentukan.',
            ),
          ] else if (body != null)
            Text(
              body!,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
        ],
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  final Color color;
  final String label;
  final String desc;

  const _ColorRow({
    required this.color,
    required this.label,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
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

// ── Add/Edit Budget Bottom Sheet ──────────────────────────────────────────────

class _AddEditBudgetSheet extends ConsumerStatefulWidget {
  final BudgetStatus? existingStatus;
  final List<CategoryModel> availableCategories;
  final List<CategoryModel> allCategories;
  final DateTime selectedMonth;

  const _AddEditBudgetSheet({
    this.existingStatus,
    required this.availableCategories,
    required this.allCategories,
    required this.selectedMonth,
  });

  @override
  ConsumerState<_AddEditBudgetSheet> createState() => _AddEditBudgetSheetState();
}

class _AddEditBudgetSheetState extends ConsumerState<_AddEditBudgetSheet> {
  CategoryModel? _selectedCategory;
  final _amountController = TextEditingController();
  bool _isSaving = false;

  bool get _isEditing => widget.existingStatus != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final status = widget.existingStatus!;
      // Find category from allCategories
      try {
        _selectedCategory = widget.allCategories
            .firstWhere((c) => c.id == status.budget.categoryId);
      } catch (_) {}
      _amountController.text =
          status.budget.monthlyLimit.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedCategory == null) return;
    final rawAmount = _amountController.text.replaceAll('.', '').replaceAll(',', '');
    final amount = double.tryParse(rawAmount);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan jumlah budget yang valid')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      const uuid = Uuid();
      final budget = BudgetModel(
        id: _isEditing ? widget.existingStatus!.budget.id : uuid.v4(),
        categoryId: _selectedCategory!.id,
        monthlyLimit: amount,
        createdAt: _isEditing
            ? widget.existingStatus!.budget.createdAt
            : DateTime.now(),
      );
      await FirebaseService().setBudget(budget);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withAlpha(77),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text(
            _isEditing ? 'Edit Budget' : 'Tambah Budget',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),

          // Category picker
          Text(
            'Kategori',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _isEditing && _selectedCategory != null
              // When editing, show fixed category
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorderDark),
                  ),
                  child: Row(
                    children: [
                      Text(_selectedCategory!.icon,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Text(
                        _selectedCategory!.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              : _CategoryDropdown(
                  categories: widget.availableCategories,
                  selected: _selectedCategory,
                  onChanged: (cat) => setState(() => _selectedCategory = cat),
                ),

          const SizedBox(height: 16),

          // Amount input
          Text(
            'Batas Budget Bulanan (Rp)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Contoh: 1000000',
              hintStyle: TextStyle(color: AppColors.textSecondary),
              prefixText: 'Rp ',
              prefixStyle: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: AppColors.darkCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.glassBorderDark),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.glassBorderDark),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),

          const SizedBox(height: 24),

          GradientButton(
            text: _isSaving ? 'Menyimpan...' : (_isEditing ? 'Update Budget' : 'Simpan Budget'),
            isLoading: _isSaving,
            onPressed: (_selectedCategory != null) ? _save : null,
            icon: Icons.save,
          ),
        ],
      ),
    );
  }
}

// ── Category Dropdown ─────────────────────────────────────────────────────────

class _CategoryDropdown extends StatelessWidget {
  final List<CategoryModel> categories;
  final CategoryModel? selected;
  final ValueChanged<CategoryModel?> onChanged;

  const _CategoryDropdown({
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorderDark),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CategoryModel>(
          value: selected,
          hint: Text(
            'Pilih kategori pengeluaran',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          isExpanded: true,
          dropdownColor: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
          onChanged: onChanged,
          items: categories.map((cat) {
            return DropdownMenuItem<CategoryModel>(
              value: cat,
              child: Row(
                children: [
                  Text(cat.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Text(
                    cat.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
