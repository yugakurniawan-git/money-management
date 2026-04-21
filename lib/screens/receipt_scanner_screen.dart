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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal scan struk: $e')),
        );
      }
    }
  }

  Future<void> _saveItems() async {
    var accounts = ref.read(accountsProvider).value ?? [];
    if (accounts.isEmpty) {
      final defaultAccount = AccountModel(
        id: const Uuid().v4(),
        bankName: 'Kas',
        accountNumber: '',
        ownerName: '',
        accountType: 'cash',
        balance: 0,
        balanceUpdatedAt: DateTime.now(),
      );
      await FirebaseService().addAccount(defaultAccount);
      accounts = [defaultAccount];
    }

    setState(() => _isSaving = true);

    try {
      final accountId = accounts.first.id;
      final categories = ref.read(categoriesProvider).value ?? [];
      final categorizer = CategorizerService();
      final now = DateTime.now();
      const uuid = Uuid();

      final transactions = _scannedItems!.map((item) {
        final categoryId = categorizer.categorize(item.name, categories) ?? 'Lainnya';
        return TransactionModel(
          id: uuid.v4(),
          accountId: accountId,
          amount: item.amount,
          description: item.name,
          rawDescription: item.name,
          categoryId: categoryId,
          transactionType: 'debit',
          transactionDate: now,
          balanceAfter: 0,
          note: 'Dari scan struk',
          importHash: '${now.millisecondsSinceEpoch}_${item.name}',
          createdAt: now,
        );
      }).toList();

      await FirebaseService().addTransactions(transactions);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${transactions.length} transaksi berhasil disimpan!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
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
