import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/goal.dart';
import '../../providers/goal_provider.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/gradient_button.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tujuan Keuangan'),
        actions: [
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
      body: goalsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (goals) {
          final completed = goals.where((g) => g.isCompleted).length;
          return Column(
            children: [
              // Summary bar
              if (goals.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$completed dari ${goals.length} tujuan tercapai',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${goals.isEmpty ? 0 : (completed / goals.length * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: goals.isEmpty
                    ? _EmptyGoals(
                        onAdd: () => _showAddEditSheet(context, ref),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: goals.length,
                        itemBuilder: (context, index) {
                          final goal = goals[index];
                          return _GoalCard(
                            goal: goal,
                            onEdit: () =>
                                _showAddEditSheet(context, ref, existing: goal),
                            onDelete: () => _confirmDelete(context, goal.id),
                            onTopUp: () =>
                                _showTopUpDialog(context, ref, goal),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditSheet(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Tambah Tujuan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _showAddEditSheet(BuildContext context, WidgetRef ref,
      {GoalModel? existing}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditGoalSheet(existing: existing),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String goalId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Tujuan?'),
        content: const Text('Tujuan ini akan dihapus permanen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseService().deleteGoal(goalId);
    }
  }

  Future<void> _showTopUpDialog(
      BuildContext context, WidgetRef ref, GoalModel goal) async {
    final controller = TextEditingController();
    final confirm = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Tabung ke "${goal.title}"'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            prefixText: 'Rp ',
            hintText: 'Nominal',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          GestureDetector(
            onTap: () {
              final amount = double.tryParse(controller.text) ?? 0;
              if (amount > 0) Navigator.pop(context, amount);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Tabung',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
    if (confirm != null && confirm > 0) {
      final updated =
          goal.copyWith(savedAmount: goal.savedAmount + confirm);
      await FirebaseService().setGoal(updated);
    }
  }

  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GoalHelpSheet(),
    );
  }
}

// ── GoalCard ──────────────────────────────────────────────────────────────────

class _GoalCard extends ConsumerWidget {
  final GoalModel goal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTopUp;

  const _GoalCard({
    required this.goal,
    required this.onEdit,
    required this.onDelete,
    required this.onTopUp,
  });

  static final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  static final _dateFmt = DateFormat('d MMM yyyy', 'id_ID');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(goalStatsProvider(goal));

    final Color progressColor = goal.isCompleted
        ? const Color(0xFF43A047)
        : stats.isOnTrack
            ? AppColors.primary
            : const Color(0xFFFF9800);

    return GestureDetector(
      onTap: onEdit,
      onLongPress: onDelete,
      child: GlassContainer(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Text(goal.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    goal.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (goal.isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF43A047).withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF43A047).withAlpha(100)),
                    ),
                    child: const Text(
                      '✓ Tercapai!',
                      style: TextStyle(
                        color: Color(0xFF43A047),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goal.progress,
                backgroundColor: AppColors.darkCard,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),

            // Amount info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_currency.format(goal.savedAmount)} dari ${_currency.format(goal.targetAmount)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${(goal.progress * 100).toStringAsFixed(0)}% tercapai',
                  style: TextStyle(
                    fontSize: 12,
                    color: progressColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            // ETA info
            if (!goal.isCompleted) ...[
              const SizedBox(height: 6),
              if (goal.targetDate != null) ...[
                Text(
                  'Target: ${_dateFmt.format(goal.targetDate!)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (stats.monthlySavingNeeded > 0)
                  Text(
                    'Perlu nabung ${_currency.format(stats.monthlySavingNeeded)}/bulan',
                    style: TextStyle(
                      fontSize: 11,
                      color: stats.isOnTrack
                          ? const Color(0xFF43A047)
                          : const Color(0xFFFF9800),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ] else if (stats.monthsToGoal != null) ...[
                Text(
                  'Dengan saving saat ini, ~${stats.monthsToGoal} bulan lagi',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],

            const SizedBox(height: 10),

            // Tombol Tabung
            if (!goal.isCompleted)
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: onTopUp,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '+ Tabung',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── EmptyGoals ────────────────────────────────────────────────────────────────

class _EmptyGoals extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyGoals({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              child: const Icon(Icons.flag_outlined,
                  color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Belum ada tujuan keuangan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Buat tujuan untuk membantu kamu menabung dengan lebih terarah',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 28),
            GradientButton(
              text: 'Buat Tujuan Pertama',
              icon: Icons.add,
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

// ── AddEditGoalSheet ──────────────────────────────────────────────────────────

class _AddEditGoalSheet extends ConsumerStatefulWidget {
  final GoalModel? existing;
  const _AddEditGoalSheet({this.existing});

  @override
  ConsumerState<_AddEditGoalSheet> createState() => _AddEditGoalSheetState();
}

class _AddEditGoalSheetState extends ConsumerState<_AddEditGoalSheet> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _savedController = TextEditingController();
  String _selectedEmoji = '🎯';
  DateTime? _targetDate;
  bool _isSaving = false;

  static const _emojis = [
    '🚗', '🏠', '✈️', '💍', '📱', '🎓', '💰', '🏖️', '🛒', '🎯'
  ];

  static final _dateFmt = DateFormat('d MMM yyyy', 'id_ID');

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final g = widget.existing!;
      _titleController.text = g.title;
      _targetController.text = g.targetAmount.toStringAsFixed(0);
      _savedController.text =
          g.savedAmount > 0 ? g.savedAmount.toStringAsFixed(0) : '';
      _selectedEmoji = g.emoji;
      _targetDate = g.targetDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _savedController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final target = double.tryParse(_targetController.text) ?? 0;
    if (title.isEmpty || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nama tujuan dan target jumlah wajib diisi')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final saved = double.tryParse(_savedController.text) ?? 0;
    final goal = GoalModel(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: title,
      emoji: _selectedEmoji,
      targetAmount: target,
      savedAmount: saved,
      targetDate: _targetDate,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    await FirebaseService().setGoal(goal);
    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 180)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2099),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
            Text(
              widget.existing != null ? 'Edit Tujuan' : 'Tambah Tujuan',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            // Emoji picker
            Wrap(
              spacing: 8,
              children: _emojis.map((e) {
                final selected = e == _selectedEmoji;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = e),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withAlpha(40)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary.withAlpha(60),
                      ),
                    ),
                    child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Nama Tujuan
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Nama Tujuan',
                hintText: 'Misal: Beli Motor',
              ),
            ),
            const SizedBox(height: 12),

            // Target Jumlah
            TextField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Target Jumlah',
                prefixText: 'Rp ',
                hintText: '10000000',
              ),
            ),
            const SizedBox(height: 12),

            // Sudah Ditabung
            TextField(
              controller: _savedController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Sudah Ditabung (opsional)',
                prefixText: 'Rp ',
                hintText: '0',
              ),
            ),
            const SizedBox(height: 12),

            // Target Tanggal
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: AppColors.textSecondary.withAlpha(100)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        color: AppColors.textSecondary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _targetDate != null
                            ? 'Target: ${_dateFmt.format(_targetDate!)}'
                            : 'Target Tanggal (opsional)',
                        style: TextStyle(
                          color: _targetDate != null
                              ? null
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (_targetDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _targetDate = null),
                        child: Icon(Icons.close,
                            color: AppColors.textSecondary, size: 18),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            GradientButton(
              text: 'Simpan',
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

// ── GoalHelpSheet ─────────────────────────────────────────────────────────────

class _GoalHelpSheet extends StatelessWidget {
  const _GoalHelpSheet();

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
            'Cara Kerja Tujuan Keuangan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _HelpItem(
            emoji: '🎯',
            title: 'Buat Tujuan',
            desc:
                'Tentukan nama, jumlah target, dan tanggal kapan kamu ingin mencapainya.',
          ),
          _HelpItem(
            emoji: '💰',
            title: 'Tabung Secara Bertahap',
            desc:
                'Tekan tombol "+ Tabung" untuk mencatat setoran ke tujuan tersebut.',
          ),
          _HelpItem(
            emoji: '📊',
            title: 'Pantau Progress',
            desc:
                'App akan menghitung berapa yang perlu kamu tabung per bulan agar tepat waktu.',
          ),
          _HelpItem(
            emoji: '✅',
            title: 'Tandai Selesai',
            desc:
                'Tujuan otomatis tandai "Tercapai!" ketika tabungan sudah mencapai target.',
          ),
        ],
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final String emoji;
  final String title;
  final String desc;
  const _HelpItem(
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
