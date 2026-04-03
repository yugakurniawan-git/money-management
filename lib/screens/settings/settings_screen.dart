import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/account.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/account_provider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/staggered_list_animation.dart';
import '../../widgets/common/gradient_button.dart';
import '../categories/category_screen.dart';
import '../investasi/investasi_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User info card with gradient
          StaggeredListItem(
            index: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(60),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white38, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: user?.photoURL != null
                          ? Image.network(user!.photoURL!, fit: BoxFit.cover)
                          : Container(
                              color: Colors.white.withAlpha(38),
                              child: const Icon(Icons.person,
                                  color: Colors.white, size: 28),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? user?.email?.split('@')[0] ?? 'Pengguna',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (user?.email != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            user!.email!,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Theme toggle
          StaggeredListItem(
            index: 1,
            child: GlassContainer(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(isDark ? Icons.dark_mode : Icons.light_mode,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Mode Gelap',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  Switch(
                    value: isDark,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      ref.read(themeProvider.notifier).state =
                          val ? ThemeMode.dark : ThemeMode.light;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Kelola Kategori
          StaggeredListItem(
            index: 2,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoryScreen()),
              ),
              child: GlassContainer(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.category_outlined,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Kelola Kategori',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    Icon(Icons.chevron_right,
                        color: AppColors.textSecondary, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Investasi & Saham
          StaggeredListItem(
            index: 3,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InvestasiScreen()),
              ),
              child: GlassContainer(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.trending_up,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Investasi & Saham',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          Text('Watchlist dan uang dingin',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: AppColors.textSecondary, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Accounts section
          StaggeredListItem(
            index: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('REKENING BCA',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    )),
                GestureDetector(
                  onTap: () => _showAddAccountDialog(context),
                  child: ShaderMask(
                    shaderCallback: (bounds) =>
                        AppColors.primaryGradient.createShader(bounds),
                    child: const Text(
                      '+ Tambah',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          accountsAsync.when(
            loading: () => Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Text('Error: $e'),
            data: (accounts) {
              if (accounts.isEmpty) {
                return StaggeredListItem(
                  index: 3,
                  child: GlassContainer(
                    child: Text(
                      'Belum ada rekening. Tambah rekening BCA kamu.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }
              return Column(
                children: accounts.asMap().entries.map((e) {
                  final acc = e.value;
                  return StaggeredListItem(
                    index: 3 + e.key,
                    child: GlassContainer(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF005BAC).withAlpha(38),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text('BCA',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF005BAC),
                                  )),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(acc.ownerName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                Text(
                                  acc.maskedAccountNumber,
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
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 28),

          // Reset Data
          StaggeredListItem(
            index: 5,
            child: GradientButton(
              text: 'Reset Semua Data',
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)],
              ),
              icon: Icons.delete_sweep_outlined,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Reset Semua Data?'),
                    content: const Text(
                        'Semua transaksi dan rekening akan dihapus permanen. Kategori tetap dipertahankan.\n\nTindakan ini tidak bisa dibatalkan.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal')),
                      GestureDetector(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Hapus Semua',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await FirebaseService().resetAllData();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Semua data berhasil direset')),
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 12),

          // Logout
          StaggeredListItem(
            index: 6,
            child: GradientButton(
              text: 'Keluar',
              gradient: AppColors.expenseGradient,
              icon: Icons.logout,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Keluar?'),
                    content: const Text(
                        'Kamu akan keluar dari akun ini.'),
                    actions: [
                      TextButton(
                          onPressed: () =>
                              Navigator.pop(context, false),
                          child: const Text('Batal')),
                      GestureDetector(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: AppColors.expenseGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Keluar',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(authServiceProvider).signOut();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    final ownerController = TextEditingController();
    final accountNumberController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tambah Rekening BCA'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ownerController,
              decoration: const InputDecoration(
                  hintText: 'Nama Pemilik (contoh: Yuga)'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: accountNumberController,
              decoration:
                  const InputDecoration(hintText: 'Nomor Rekening'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          GestureDetector(
            onTap: () async {
              await FirebaseService().addAccount(AccountModel(
                id: const Uuid().v4(),
                bankName: 'BCA',
                accountNumber: accountNumberController.text,
                ownerName: ownerController.text,
                balanceUpdatedAt: DateTime.now(),
              ));
              if (context.mounted) Navigator.pop(context);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Simpan',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
