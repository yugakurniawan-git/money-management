import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/account.dart';
import '../../models/transaction.dart';
import '../../providers/account_provider.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/glass_container.dart';

final _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

/// Parse berbagai format angka BCA / umum:
/// "52,853.71" → 52853.71   (koma=ribuan, titik=desimal)
/// "52.853,71" → 52853.71   (titik=ribuan, koma=desimal)
/// "52.853"    → 52853.0    (titik=ribuan)
/// "52853.71"  → 52853.71   (titik=desimal)
/// "500000"    → 500000.0
double _parseCurrency(String raw) {
  raw = raw.trim().replaceAll(' ', '');
  if (raw.isEmpty) return 0;

  final hasComma = raw.contains(',');
  final hasDot = raw.contains('.');

  if (hasComma && hasDot) {
    // Separator terakhir = desimal
    final lastComma = raw.lastIndexOf(',');
    final lastDot = raw.lastIndexOf('.');
    if (lastDot > lastComma) {
      // Format BCA: 52,853.71
      return double.tryParse(raw.replaceAll(',', '')) ?? 0;
    } else {
      // Format ID: 52.853,71
      return double.tryParse(raw.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
    }
  }

  if (hasComma && !hasDot) {
    final afterComma = raw.split(',').last;
    return afterComma.length == 2
        ? double.tryParse(raw.replaceAll(',', '.')) ?? 0   // 52853,71
        : double.tryParse(raw.replaceAll(',', '')) ?? 0;   // 52,853
  }

  if (hasDot && !hasComma) {
    final afterDot = raw.split('.').last;
    return afterDot.length == 3
        ? double.tryParse(raw.replaceAll('.', '')) ?? 0    // 52.853
        : double.tryParse(raw) ?? 0;                       // 52853.71
  }

  return double.tryParse(raw) ?? 0;
}

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dompet & Saldo')),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (accounts) {
          final totalSaldo = accounts.fold(0.0, (sum, a) => sum + a.balance);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Total saldo card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Saldo', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(
                      _idr.format(totalSaldo),
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: accounts.isEmpty ? null : () => _showTarikTunaiDialog(context, ref, accounts),
                        icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                        label: const Text('Tarik Tunai (ATM → Kas)', style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (accounts.isEmpty)
                GlassContainer(
                  child: Center(
                    child: Text('Belum ada akun. Tambah akun di bawah.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              else
                ...accounts.map((acc) => _AccountCard(account: acc)),

              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _showAddAccountDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Akun'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTarikTunaiDialog(BuildContext context, WidgetRef ref, List<AccountModel> accounts) {
    final bankAccounts = accounts.where((a) => a.accountType == 'bank').toList();
    final kasAccounts = accounts.where((a) => a.accountType == 'cash').toList();

    if (bankAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada akun bank/debit. Tambah dulu di halaman ini.')),
      );
      return;
    }

    AccountModel selectedBank = bankAccounts.first;
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Tarik Tunai'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<AccountModel>(
                value: selectedBank,
                decoration: const InputDecoration(labelText: 'Dari akun bank'),
                items: bankAccounts
                    .map((a) => DropdownMenuItem(value: a, child: Text(a.bankName)))
                    .toList(),
                onChanged: (val) => setState(() => selectedBank = val!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Jumlah tarik (Rp)', hintText: '500000'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            TextButton(
              onPressed: () async {
                final amount = _parseCurrency(amountController.text);
                if (amount <= 0) return;

                Navigator.pop(ctx);

                // Cari atau buat akun Kas
                AccountModel kasAccount;
                if (kasAccounts.isNotEmpty) {
                  kasAccount = kasAccounts.first;
                } else {
                  kasAccount = AccountModel(
                    id: const Uuid().v4(),
                    bankName: 'Kas',
                    accountNumber: '',
                    ownerName: '',
                    accountType: 'cash',
                    balance: 0,
                    balanceUpdatedAt: DateTime.now(),
                  );
                  await FirebaseService().addAccount(kasAccount);
                }

                final now = DateTime.now();
                final service = FirebaseService();

                // Catat transaksi transfer
                await service.addTransaction(TransactionModel(
                  id: const Uuid().v4(),
                  accountId: selectedBank.id,
                  toAccountId: kasAccount.id,
                  amount: amount,
                  description: 'Tarik Tunai ke Kas',
                  rawDescription: 'Tarik Tunai ke Kas',
                  categoryId: 'Transfer',
                  transactionType: 'transfer',
                  transactionDate: now,
                  balanceAfter: selectedBank.balance - amount,
                  note: '',
                  importHash: 'tarik_tunai_${now.millisecondsSinceEpoch}',
                  createdAt: now,
                ));

                // Update saldo kedua akun
                await service.updateAccount(selectedBank.copyWith(
                  balance: selectedBank.balance - amount,
                  balanceUpdatedAt: now,
                ));
                await service.updateAccount(kasAccount.copyWith(
                  balance: kasAccount.balance + amount,
                  balanceUpdatedAt: now,
                ));

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tarik tunai ${_idr.format(amount)} berhasil')),
                  );
                }
              },
              child: const Text('Tarik'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    String selectedType = 'bank';
    final nameController = TextEditingController();
    final numberController = TextEditingController();
    final balanceController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Tambah Akun'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Jenis Akun'),
                items: const [
                  DropdownMenuItem(value: 'bank', child: Text('Bank / Debit / QRIS')),
                  DropdownMenuItem(value: 'cash', child: Text('Kas / Tunai')),
                  DropdownMenuItem(value: 'ewallet', child: Text('E-Wallet (GoPay, OVO, dll)')),
                ],
                onChanged: (v) => setState(() => selectedType = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nama akun', hintText: 'BCA, Mandiri, Kas...'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: numberController,
                decoration: const InputDecoration(labelText: 'Nomor rekening (opsional)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balanceController,
                decoration: const InputDecoration(labelText: 'Saldo awal (Rp)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            TextButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                final balance = _parseCurrency(balanceController.text);
                await FirebaseService().addAccount(AccountModel(
                  id: const Uuid().v4(),
                  bankName: nameController.text,
                  accountNumber: numberController.text,
                  ownerName: '',
                  accountType: selectedType,
                  balance: balance,
                  balanceUpdatedAt: DateTime.now(),
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  final AccountModel account;
  const _AccountCard({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = switch (account.accountType) {
      'cash' => Icons.money,
      'ewallet' => Icons.account_balance_wallet,
      _ => Icons.credit_card,
    };

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.bankName, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  _idr.format(account.balance),
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
            onPressed: () => _showEditSaldoDialog(context, account),
          ),
        ],
      ),
    );
  }

  void _showEditSaldoDialog(BuildContext context, AccountModel account) {
    final controller = TextEditingController(text: account.balance.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Saldo ${account.bankName}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Saldo saat ini (Rp)'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              final balance = _parseCurrency(controller.text);
              if (balance <= 0 && controller.text.trim() == '0') return;
              await FirebaseService().updateAccount(account.copyWith(
                balance: balance,
                balanceUpdatedAt: DateTime.now(),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
