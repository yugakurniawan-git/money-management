import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/transaction_item.dart';
import '../services/ai_receipt_service.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({Key? key}) : super(key: key);

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  final AIReceiptService _aiService = AIReceiptService();
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = false;
  File? _imageFile;
  List<TransactionItem>? _scannedItems;

  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80, // Kompres sedikit agar API tidak terlalu mahal
    );

    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
        _isLoading = true;
        _scannedItems = null;
      });

      try {
        final bytes = await _imageFile!.readAsBytes();
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
                        Text('AI AI sedang membaca rincian belanjaanmu...'),
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
                onPressed: () {
                  // TODO: Lempar/return List<TransactionItem> ini ke halaman "Add Transaction"
                  // Navigator.pop(context, _scannedItems);
                },
                child: const Text('Gunakan Rincian Ini'),
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
