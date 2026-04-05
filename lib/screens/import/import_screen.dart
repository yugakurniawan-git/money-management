import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_colors.dart';
import '../../providers/account_provider.dart';
import '../../services/csv_parser_service.dart';
import '../../services/pdf_parser_service.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/staggered_list_animation.dart';
import 'import_preview_screen.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _error;
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _pickAndParseFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'CSV', 'pdf', 'PDF'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final file = result.files.first;
      final fileName = file.name.toLowerCase();
      final isPdf = fileName.endsWith('.pdf');

      final accounts = ref.read(accountsProvider).value ?? [];
      final accountId = accounts.isNotEmpty ? accounts.first.id : 'default';

      List<dynamic> transactions;
      BcaPdfSummary? pdfSummary;
      PdfParserService? pdfParser;

      if (isPdf) {
        // Parse PDF
        final Uint8List pdfBytes;
        if (file.bytes != null) {
          pdfBytes = file.bytes!;
        } else {
          throw Exception('Tidak bisa membaca file PDF. Coba upload ulang.');
        }

        debugPrint('=== PDF file loaded: ${pdfBytes.length} bytes ===');

        pdfParser = PdfParserService();
        final pdfResult = await pdfParser.parseBcaPdf(pdfBytes, accountId);
        transactions = pdfResult.transactions;
        pdfSummary = pdfResult.summary;

      } else {
        // Parse CSV
        final String csvContent;
        if (file.bytes != null) {
          csvContent = String.fromCharCodes(file.bytes!);
        } else {
          throw Exception('Tidak bisa membaca file CSV. Coba upload ulang.');
        }

        final parser = CsvParserService();
        final csvResult = parser.parseBcaCsv(csvContent, accountId);
        transactions = csvResult.transactions;
        pdfSummary = csvResult.summary;
      }

      if (transactions.isEmpty) {
        if (isPdf && pdfParser != null) {
          final debugInfo = pdfParser.getDebugLines(50);
          setState(() => _error = 'DEBUG lines:\n$debugInfo');
        } else {
          setState(() => _error = 'Tidak ada transaksi ditemukan di file CSV');
        }
        return;
      }

      if (!mounted) return;

      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, anim, __) => ImportPreviewScreen(
            transactions: transactions.cast(),
            fileName: file.name,
            pdfSummary: pdfSummary,
          ),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('=== IMPORT ERROR: $e ===');
      debugPrint('=== STACK TRACE: $stackTrace ===');
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Transaksi'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Floating upload icon
              StaggeredListItem(
                index: 0,
                child: AnimatedBuilder(
                  animation: _floatController,
                  builder: (context, child) {
                    final offset =
                        Tween<double>(begin: -8, end: 0)
                            .animate(CurvedAnimation(
                              parent: _floatController,
                              curve: Curves.easeInOut,
                            ))
                            .value;
                    return Transform.translate(
                      offset: Offset(0, offset),
                      child: child,
                    );
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(80),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.upload_file,
                        color: Colors.white, size: 40),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              StaggeredListItem(
                index: 1,
                child: Text(
                  'Import Mutasi BCA',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 10),

              StaggeredListItem(
                index: 2,
                child: Text(
                  'Upload file CSV atau PDF rekening koran\ndari myBCA atau KlikBCA.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 28),

              // Steps for CSV
              StaggeredListItem(
                index: 3,
                child: GlassContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.income.withAlpha(26),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('CSV',
                                style: TextStyle(
                                  color: AppColors.income,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                          const SizedBox(width: 8),
                          Text('Dari myBCA / KlikBCA:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              )),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _step(1, 'Buka myBCA > Rekening > Mutasi'),
                      _step(2, 'Pilih periode > Export / Download CSV'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Steps for PDF
              StaggeredListItem(
                index: 4,
                child: GlassContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.expense.withAlpha(26),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('PDF',
                                style: TextStyle(
                                  color: AppColors.expense,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                          const SizedBox(width: 8),
                          Text('Rekening Koran KlikBCA:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              )),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _step(1, 'Login KlikBCA > e-Statement'),
                      _step(2, 'Pilih bulan > Download PDF'),
                      _step(3, 'Upload file PDF di sini'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.expense),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],

              StaggeredListItem(
                index: 5,
                child: GradientButton(
                  text: _isLoading ? 'Memproses...' : 'Pilih File CSV / PDF',
                  isLoading: _isLoading,
                  onPressed: _pickAndParseFile,
                  icon: Icons.file_open,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(int num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text(
                '$num',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
