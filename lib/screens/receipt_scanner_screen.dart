import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/transaction_item.dart';
import '../providers/account_provider.dart';
import '../providers/category_provider.dart';
import '../services/ai_receipt_service.dart';
import '../services/categorizer_service.dart';
import '../services/firebase_service.dart';

// Pilihan metode pembayaran
class _PaymentMethod {
  final String label;
  final String description;
  final IconData icon;
  final String bankName;
  final String accountType;

  const _PaymentMethod({
    required this.label,
    required this.description,
    required this.icon,
    required this.bankName,
    required this.accountType,
  });
}

const _paymentMethods = [
  _PaymentMethod(
    label: 'Debit / QRIS',
    description: 'Bayar lewat kartu debit atau scan QRIS',
    icon: Icons.credit_card,
    bankName: 'Debit / QRIS',
    accountType: 'bank',
  ),
  _PaymentMethod(
    label: 'Kas / Tunai',
    description: 'Bayar pakai uang cash',
    icon: Icons.money,
    bankName: 'Kas',
    accountType: 'cash',
  ),
  _PaymentMethod(
    label: 'Kartu Kredit',
    description: 'Bayar lewat kartu kredit',
    icon: Icons.credit_score,
    bankName: 'Kartu Kredit',
    accountType: 'bank',
  ),
];

class ReceiptScannerScreen extends ConsumerStatefulWidget {
  const ReceiptScannerScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends ConsumerState<ReceiptScannerScreen> {
  final AIReceiptService _aiService = AIReceiptService();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isSaving = false;
  List<TransactionItem>? _scannedItems;

  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _isLoading = true;
        _scannedItems = null;
      });

      try {
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);
        final items = await _aiService.scanReceiptItems(base64Image);
        setState(() {
          _scannedItems = items;
          _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal scan struk: $e')),
          );
        }
      }
    }
  }

  Future<_PaymentMethod?> _showPaymentMethodPicker() {
    return showModalBottomSheet<_PaymentMethod>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bayar pakai apa?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pilih metode pembayaran agar tidak double pencatatan',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ..._paymentMethods.map((method) => ListTile(
                  leading: Icon(method.icon),
                  title: Text(method.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(method.description, style: const TextStyle(fontSize: 12)),
                  onTap: () => Navigator.pop(ctx, method),
                )),
          ],
        ),
      ),
    );
  }

  Future<AccountModel> _getOrCreateAccount(_PaymentMethod method, List<AccountModel> accounts) async {
    // Cari akun yang sudah ada dengan nama yang sama
    final existing = accounts.where((a) => a.bankName == method.bankName).firstOrNull;
    if (existing != null) return existing;

    // Buat akun baru jika belum ada
    final newAccount = AccountModel(
      id: const Uuid().v4(),
      bankName: method.bankName,
      accountNumber: '',
      ownerName: '',
      accountType: method.accountType,
      balance: 0,
      balanceUpdatedAt: DateTime.now(),
    );
    await FirebaseService().addAccount(newAccount);
    return newAccount;
  }

  Future<void> _saveItems() async {
    final selectedMethod = await _showPaymentMethodPicker();
    if (selectedMethod == null || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final accounts = ref.read(accountsProvider).value ?? [];
      final account = await _getOrCreateAccount(selectedMethod, accounts);

      final categories = ref.read(categoriesProvider).value ?? [];
      final categorizer = CategorizerService();
      final now = DateTime.now();
      const uuid = Uuid();

      final transactions = _scannedItems!.map((item) {
        final categoryId = categorizer.categorize(item.name, categories) ?? 'Lainnya';
        return TransactionModel(
          id: uuid.v4(),
          accountId: account.id,
          amount: item.amount,
          description: item.name,
          rawDescription: item.name,
          categoryId: categoryId,
          transactionType: 'debit',
          transactionDate: now,
          balanceAfter: 0,
          note: 'Dari scan struk (${selectedMethod.label})',
          importHash: '${now.millisecondsSinceEpoch}_${item.name}',
          createdAt: now,
        );
      }).toList();

      await FirebaseService().addTransactions(transactions);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${transactions.length} transaksi disimpan ke ${selectedMethod.label}')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Struk Belanja')),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('AI sedang membaca rincian belanjaanmu...'),
                      ],
                    ),
                  )
                : _scannedItems == null
                    ? const Center(child: Text('Belum ada struk. Tekan tombol kamera di bawah.'))
                    : ListView.builder(
                        itemCount: _scannedItems!.length,
                        itemBuilder: (context, index) {
                          final item = _scannedItems![index];
                          return ListTile(
                            title: Text(item.name),
                            subtitle: Text('Kategori: ${item.categoryId}'),
                            trailing: Text('Rp ${item.amount.toStringAsFixed(0)}'),
                          );
                        },
                      ),
          ),
          if (_scannedItems != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveItems,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Gunakan Rincian Ini'),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _takePhoto,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
