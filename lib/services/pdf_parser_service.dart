import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';

/// Summary info extracted from BCA bank statement footer
class BcaPdfSummary {
  final double saldoAwal;
  final double saldoAkhir;
  final double mutasiCr;
  final double mutasiDb;
  final int countCr;
  final int countDb;
  final String periode;
  final String noRekening;

  BcaPdfSummary({
    this.saldoAwal = 0,
    this.saldoAkhir = 0,
    this.mutasiCr = 0,
    this.mutasiDb = 0,
    this.countCr = 0,
    this.countDb = 0,
    this.periode = '',
    this.noRekening = '',
  });
}

/// Result from parsing BCA PDF statement
class BcaPdfResult {
  final List<TransactionModel> transactions;
  final BcaPdfSummary summary;

  BcaPdfResult({required this.transactions, required this.summary});
}

class PdfParserService {
  final _uuid = const Uuid();

  /// BCA MUTASI/SALDO column format: comma=thousands, dot=decimal
  /// Matches: 6,000.00 | 150,000.00 | 14,129,963.00 | 80,527.71
  /// Does NOT match: 150000.00 | 00000.00 | 089506585454
  static final RegExp _bcaAmount = RegExp(
    r'(\d{1,3}(?:,\d{3})+\.\d{2})',
  );

  /// Merchant name stuck after 00000.00 prefix in QR transactions
  static final RegExp _merchantPrefix = RegExp(r'00000\.00(.+)');

  /// Parse BCA bank statement PDF (rekening koran)
  BcaPdfResult parseBcaPdf(Uint8List pdfBytes, String accountId) {
    debugPrint('=== Starting PDF parse, ${pdfBytes.length} bytes ===');

    late PdfDocument document;
    try {
      document = PdfDocument(inputBytes: pdfBytes);
    } catch (e) {
      debugPrint('=== SYNCFUSION PDF ERROR: $e ===');
      throw Exception('Gagal membuka PDF: $e');
    }

    final allText = <String>[];
    try {
      for (int i = 0; i < document.pages.count; i++) {
        final extractor = PdfTextExtractor(document);
        final text =
            extractor.extractText(startPageIndex: i, endPageIndex: i);
        allText.add(text);
      }
    } catch (e) {
      debugPrint('=== PDF TEXT EXTRACTION ERROR: $e ===');
      document.dispose();
      throw Exception('Gagal extract teks dari PDF: $e');
    }
    document.dispose();

    final fullText = allText.join('\n');
    final lines = const LineSplitter().convert(fullText);

    // Debug: print first 50 lines to console
    debugPrint('=== PDF TEXT EXTRACTION (first 50 lines) ===');
    for (int i = 0; i < lines.length && i < 50; i++) {
      debugPrint('LINE $i: [${lines[i]}]');
    }
    debugPrint('=== TOTAL LINES: ${lines.length} ===');

    final year = _detectYear(lines);
    final summary = _parseSummary(lines);

    // Primary: structured line-by-line parsing (no header detection needed)
    var transactions = _parseTransactions(lines, accountId, year);

    // Fallback: regex-based parsing on full text
    if (transactions.isEmpty) {
      debugPrint('=== Structured parsing found 0 transactions, trying regex fallback ===');
      transactions = _parseWithRegex(fullText, accountId, year);
    }

    debugPrint('=== PARSED ${transactions.length} TRANSACTIONS ===');

    return BcaPdfResult(transactions: transactions, summary: summary);
  }

  // ===== YEAR DETECTION =====

  int _detectYear(List<String> lines) {
    for (final line in lines) {
      // PERIODE : FEBRUARI 2026
      final periodeMatch = RegExp(
        r'(?:PERIODE|PERIOD)\s*:?\s*\w+\s+(20\d{2})',
        caseSensitive: false,
      ).firstMatch(line);
      if (periodeMatch != null) {
        return int.tryParse(periodeMatch.group(1)!) ?? DateTime.now().year;
      }

      // DD/MM/YYYY format
      final dateMatch = RegExp(r'(\d{2}/\d{2}/(20\d{2}))').firstMatch(line);
      if (dateMatch != null) {
        return int.tryParse(dateMatch.group(2)!) ?? DateTime.now().year;
      }
    }
    return DateTime.now().year;
  }

  // ===== SUMMARY PARSING =====

  BcaPdfSummary _parseSummary(List<String> lines) {
    double saldoAwal = 0, saldoAkhir = 0, mutasiCr = 0, mutasiDb = 0;
    int countCr = 0, countDb = 0;
    String periode = '', noRekening = '';

    for (final line in lines) {
      final trimmed = line.trim();

      // NO. REKENING : 5190176926
      if (trimmed.contains('NO') &&
          trimmed.contains('REKENING') &&
          trimmed.contains(':')) {
        final parts = trimmed.split(':');
        if (parts.length >= 2) noRekening = parts.last.trim();
      }

      // PERIODE : FEBRUARI 2026
      if (trimmed.contains('PERIODE') && trimmed.contains(':')) {
        final parts = trimmed.split(':');
        if (parts.length >= 2) {
          final p = parts.last.trim();
          if (p.isNotEmpty &&
              !p.contains('IDR') &&
              !p.contains('REKENING')) {
            periode = p;
          }
        }
      }

      // Summary section (with colon separator):
      // SALDO AWAL : 80,527.71
      var match =
          RegExp(r'SALDO\s+AWAL\s*:?\s*([\d,]+\.\d{2})').firstMatch(trimmed);
      if (match != null) {
        saldoAwal = _parseBcaAmount(match.group(1)!);
      }

      // MUTASI CR : 17,941,863.00 42
      match = RegExp(r'MUTASI\s+CR\s*:?\s*([\d,]+\.\d{2})\s+(\d+)')
          .firstMatch(trimmed);
      if (match != null) {
        mutasiCr = _parseBcaAmount(match.group(1)!);
        countCr = int.tryParse(match.group(2)!) ?? 0;
      }

      // MUTASI DB : 17,945,350.00 72
      match = RegExp(r'MUTASI\s+DB\s*:?\s*([\d,]+\.\d{2})\s+(\d+)')
          .firstMatch(trimmed);
      if (match != null) {
        mutasiDb = _parseBcaAmount(match.group(1)!);
        countDb = int.tryParse(match.group(2)!) ?? 0;
      }

      // SALDO AKHIR : 77,040.71
      match =
          RegExp(r'SALDO\s+AKHIR\s*:?\s*([\d,]+\.\d{2})').firstMatch(trimmed);
      if (match != null) {
        saldoAkhir = _parseBcaAmount(match.group(1)!);
      }
    }

    return BcaPdfSummary(
      saldoAwal: saldoAwal,
      saldoAkhir: saldoAkhir,
      mutasiCr: mutasiCr,
      mutasiDb: mutasiDb,
      countCr: countCr,
      countDb: countDb,
      periode: periode,
      noRekening: noRekening,
    );
  }

  // ===== TRANSACTION PARSING (no header detection needed) =====

  List<TransactionModel> _parseTransactions(
    List<String> lines,
    String accountId,
    int year,
  ) {
    final blocks = <_TxnBlock>[];
    _TxnBlock? current;
    bool afterTableEnd = false;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Skip page number indicators like "1 /10", "10 /10"
      if (RegExp(r'^\d{1,2}\s*/\s*\d{1,2}$').hasMatch(line)) continue;

      // Skip known non-transaction content
      if (_isSkippableLine(line)) continue;

      // Detect summary/end markers — flush current and stop accepting
      if (_isTableEnd(line)) {
        if (current != null) {
          blocks.add(current);
          current = null;
        }
        afterTableEnd = true;
        continue;
      }

      // After a table end (like Bersambung), skip until next DD/MM date
      // This handles page headers that repeat between pages

      // Check for transaction start: DD/MM followed by text
      final dateMatch = RegExp(r'^(\d{2}/\d{2})\s+(.+)').firstMatch(line);
      if (dateMatch != null) {
        afterTableEnd = false; // We're back in transaction territory

        // Flush previous block
        if (current != null) blocks.add(current);
        current = _TxnBlock(
          dateStr: dateMatch.group(1)!,
          lines: [dateMatch.group(2)!],
        );
        continue;
      }

      // Skip continuation lines if we're in a header area between pages
      if (afterTableEnd) continue;

      // Continuation line — append to current block
      if (current != null) {
        current.lines.add(line);
      }
    }

    // Flush last block
    if (current != null) blocks.add(current);

    debugPrint('=== Found ${blocks.length} transaction blocks ===');

    // Parse each block into a transaction
    final transactions = <TransactionModel>[];
    for (final block in blocks) {
      final txn = _parseBlock(block, accountId, year);
      if (txn != null) {
        transactions.add(txn);
        debugPrint(
            'TX: ${block.dateStr} | ${txn.transactionType} | ${txn.amount} | ${txn.description}');
      } else {
        debugPrint(
            'SKIP: ${block.dateStr} | ${block.lines.first}');
      }
    }

    return transactions;
  }

  /// Lines to always skip — header/metadata content
  bool _isSkippableLine(String line) {
    final l = line.trim();

    // Table column headers (might be one line or separate lines)
    if (l == 'TANGGAL' ||
        l == 'KETERANGAN' ||
        l == 'CBG' ||
        l == 'MUTASI' ||
        l == 'SALDO') {
      return true;
    }
    // Combined header line
    if (l.contains('TANGGAL') &&
        l.contains('KETERANGAN') &&
        l.contains('MUTASI')) {
      return true;
    }

    // Document header lines
    if (l.startsWith('REKENING') ||
        l.startsWith('KCP ') ||
        l.contains('NO. REKENING') ||
        l.contains('NO.REKENING') ||
        l.startsWith('HALAMAN') ||
        l.startsWith('PERIODE') ||
        l.startsWith('MATA UANG') ||
        l.startsWith('CATATAN')) {
      return true;
    }

    // Notice/disclaimer text
    if (l.contains('Laporan Mutasi')) return true;
    if (l.contains('nasabah tidak melakukan')) return true;
    if (l.contains('menyetujui segala')) return true;
    if (l.contains('BCA berhak')) return true;
    if (l.contains('melakukan koreksi')) return true;
    if (l.contains('akhir bulan berikutnya')) return true;
    if (l.contains('tercantum pada')) return true;

    // Address lines (before table, contain postal codes or known keywords)
    if (RegExp(r'^\d{5}\s*$').hasMatch(l)) return true; // postal code
    if (l == 'INDONESIA') return true;

    // Bullet points
    if (l == '•') return true;

    return false;
  }

  bool _isTableEnd(String line) {
    final lower = line.toLowerCase().trim();
    return lower.startsWith('bersambung') ||
        (lower.startsWith('saldo awal') && lower.contains(':')) ||
        lower.startsWith('mutasi cr') ||
        lower.startsWith('mutasi db') ||
        lower.startsWith('saldo akhir');
  }

  // ===== BLOCK PARSING =====

  TransactionModel? _parseBlock(
    _TxnBlock block,
    String accountId,
    int year,
  ) {
    // Parse date DD/MM
    final dateParts = block.dateStr.split('/');
    if (dateParts.length != 2) return null;
    final day = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    if (day == null || month == null) return null;
    if (day < 1 || day > 31 || month < 1 || month > 12) return null;
    final date = DateTime(year, month, day);

    // Join all lines for analysis
    final firstLine = block.lines.isNotEmpty ? block.lines.first : '';
    final fullText = block.lines.join(' ');

    // Detect transaction type from KETERANGAN
    final type = _detectType(firstLine, fullText);
    if (type == 'skip') return null; // SALDO AWAL entry

    // Find all BCA-formatted amounts in this block
    final amounts = _bcaAmount
        .allMatches(fullText)
        .map((m) => _parseBcaAmount(m.group(0)!))
        .where((a) => a > 0)
        .toList();

    if (amounts.isEmpty) return null;

    // First BCA amount = MUTASI, last = SALDO (if different)
    final mutasi = amounts.first;
    final saldo = amounts.length >= 2 ? amounts.last : 0.0;

    if (mutasi <= 0) return null;

    // Build clean description
    final description = _buildDescription(block.lines);
    if (description.isEmpty) return null;

    final hash = _generateHash(date, mutasi, description);

    return TransactionModel(
      id: _uuid.v4(),
      accountId: accountId,
      amount: mutasi,
      description: description,
      rawDescription: '${block.dateStr} $fullText',
      categoryId: '',
      transactionType: type,
      transactionDate: date,
      balanceAfter: saldo,
      importHash: hash,
      createdAt: DateTime.now(),
    );
  }

  // ===== TYPE DETECTION =====

  String _detectType(String firstLine, String fullText) {
    final upper = firstLine.toUpperCase();
    final fullUpper = fullText.toUpperCase();

    // Skip non-transaction entries
    if (upper.contains('SALDO AWAL')) {
      return 'skip';
    }

    // Explicit type from KETERANGAN column (check full text)
    if (fullUpper.contains('TRSF E-BANKING CR') ||
        fullUpper.contains('TRSF E BANKING CR')) {
      return 'credit';
    }
    if (fullUpper.contains('TRSF E-BANKING DB') ||
        fullUpper.contains('TRSF E BANKING DB')) {
      return 'debit';
    }
    if (fullUpper.contains('TRANSAKSI DEBIT')) {
      return 'debit';
    }
    if (fullUpper.contains('TARIKAN ATM')) {
      return 'debit';
    }
    if (fullUpper.contains('BIAYA ADM')) {
      return 'debit';
    }
    if (fullUpper.contains('KR OTOMATIS')) {
      return 'credit';
    }
    if (fullUpper.contains('BUNGA') ||
        fullUpper.contains('INTEREST') ||
        fullUpper.contains('SETORAN')) {
      return 'credit';
    }
    if (fullUpper.contains('GAJI') || fullUpper.contains('PAYROL')) {
      return 'credit';
    }

    // Check for DB marker after BCA amounts: "73,000.00 DB"
    if (RegExp(r'\d+\.\d{2}\s+DB\b').hasMatch(fullUpper)) return 'debit';

    // Default to debit (most transactions are expenses)
    return 'debit';
  }

  // ===== DESCRIPTION BUILDING =====

  String _buildDescription(List<String> rawLines) {
    final parts = <String>[];

    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i].trim();
      if (line.isEmpty || line == '-') continue;

      // --- Skip noise patterns ---

      // Reference codes: 0102/FTSCY/WS95031
      if (RegExp(r'^\d{4}/\w+/\w+').hasMatch(line)) continue;

      // Raw amounts without commas: 150000.00, 73000.00
      if (RegExp(r'^\d+\.00$').hasMatch(line)) continue;

      // Phone numbers (10+ digits): 089506585454
      if (RegExp(r'^\d{10,}$').hasMatch(line)) continue;

      // Masked phone: Q0895XXXXXX54
      if (RegExp(r'^Q\d+X+\d*').hasMatch(line)) continue;

      // Date references: TGL: 02/02, TANGGAL :08/02
      if (RegExp(r'^TGL\s*:\s*\d{2}/\d{2}', caseSensitive: false)
              .hasMatch(line) ||
          RegExp(r'^TANGGAL\s*:\s*\d{2}/\d{2}', caseSensitive: false)
              .hasMatch(line)) {
        continue;
      }

      // QR codes: QRC014, QR 002, QR 914
      if (RegExp(r'^QR\s*C?\s*\d{3}').hasMatch(line)) continue;

      // Standalone branch codes: 0938
      if (RegExp(r'^\d{4}$').hasMatch(line)) continue;

      // Lines that are ONLY BCA amounts: "150,000.00 230,527.71"
      // or: "73,000.00 DB 157,527.71" or: "100,000.00 DB"
      final lineWithoutAmounts = line
          .replaceAll(_bcaAmount, '')
          .replaceAll(RegExp(r'\bDB\b|\bCR\b'), '')
          .trim();
      if (lineWithoutAmounts.isEmpty) continue;

      // --- Extract meaningful content ---

      // Service detail: 70001/GOPAY TOPUP → "GOPAY TOPUP"
      final serviceMatch = RegExp(r'^\d{5}/(.+)').firstMatch(line);
      if (serviceMatch != null) {
        parts.add(serviceMatch.group(1)!.trim());
        continue;
      }

      // Merchant after 00000.00: "00000.00IDM INDOMA" → "IDM INDOMA"
      final merchantMatch = _merchantPrefix.firstMatch(line);
      if (merchantMatch != null) {
        parts.add(merchantMatch.group(1)!.trim());
        continue;
      }

      // First line (i==0): transaction type label
      if (i == 0) {
        var cleaned = line;
        // Remove reference code at end
        cleaned = cleaned.replaceAll(RegExp(r'\s+\d{4}/\w+/\w+'), '').trim();
        // Remove inline date at end (TARIKAN ATM 04/02)
        cleaned = cleaned.replaceAll(RegExp(r'\s+\d{2}/\d{2}$'), '').trim();
        // Remove BCA amounts
        cleaned = cleaned.replaceAll(_bcaAmount, '').trim();
        if (cleaned.isNotEmpty) parts.add(cleaned);
        continue;
      }

      // Keep any remaining meaningful text (person names, company names)
      if (RegExp(r'[A-Za-z]{2,}').hasMatch(line)) {
        var cleaned = line.replaceAll(_bcaAmount, '').trim();
        cleaned = cleaned.replaceAll(RegExp(r'\bDB\b|\bCR\b'), '').trim();
        // Remove raw amounts embedded in text
        cleaned =
            cleaned.replaceAll(RegExp(r'\b\d{3,}\.00\b'), '').trim();
        if (cleaned.isNotEmpty) parts.add(cleaned);
      }
    }

    var result = parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    // Remove stray numbers at end
    result = result.replaceAll(RegExp(r'\s+\d{1,3}$'), '').trim();

    return result;
  }

  // ===== REGEX FALLBACK =====

  /// Fallback parser using regex on the full text
  /// Used when structured line-by-line parsing fails
  List<TransactionModel> _parseWithRegex(
    String fullText,
    String accountId,
    int year,
  ) {
    final transactions = <TransactionModel>[];

    // Pattern: DD/MM followed by text, then BCA amount, optional DB, optional saldo
    final pattern = RegExp(
      r'(\d{2}/\d{2})\s+'
      r'((?:TRSF E-BANKING (?:CR|DB)|TRANSAKSI DEBIT|TARIKAN ATM|BIAYA ADM|KR OTOMATIS).+?)'
      r'\s+(\d{1,3}(?:,\d{3})+\.\d{2})'
      r'\s*(DB)?'
      r'(?:\s+(\d{1,3}(?:,\d{3})+\.\d{2}))?',
      caseSensitive: false,
      dotAll: true,
    );

    for (final match in pattern.allMatches(fullText)) {
      final dateStr = match.group(1)!;
      var description = match.group(2)!.trim();
      final amountStr = match.group(3)!;
      final isDb = match.group(4) != null;
      final balanceStr = match.group(5);

      final dateParts = dateStr.split('/');
      if (dateParts.length != 2) continue;

      final day = int.tryParse(dateParts[0]);
      final month = int.tryParse(dateParts[1]);
      if (day == null || month == null) continue;
      if (day < 1 || day > 31 || month < 1 || month > 12) continue;

      final date = DateTime(year, month, day);
      final amount = _parseBcaAmount(amountStr);
      final balance = balanceStr != null ? _parseBcaAmount(balanceStr) : 0.0;

      if (amount <= 0) continue;

      // Skip SALDO AWAL
      if (description.toUpperCase().contains('SALDO AWAL')) continue;

      // Determine type
      String type;
      final descUpper = description.toUpperCase();
      if (descUpper.contains('CR') ||
          descUpper.contains('KR OTOMATIS') ||
          descUpper.contains('BUNGA')) {
        type = 'credit';
      } else {
        type = 'debit';
      }
      if (isDb) type = 'debit';

      // Clean description
      description = description
          .replaceAll(RegExp(r'\d{4}/\w+/\w+'), '')
          .replaceAll(RegExp(r'\b\d+\.00\b'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (description.isEmpty) continue;

      final hash = _generateHash(date, amount, description);

      transactions.add(TransactionModel(
        id: _uuid.v4(),
        accountId: accountId,
        amount: amount,
        description: description,
        rawDescription: match.group(0)!,
        categoryId: '',
        transactionType: type,
        transactionDate: date,
        balanceAfter: balance,
        importHash: hash,
        createdAt: DateTime.now(),
      ));
    }

    return transactions;
  }

  // ===== AMOUNT PARSING =====

  /// Parse BCA formatted amount: 17,941,863.00 → 17941863.00
  double _parseBcaAmount(String amountStr) {
    return double.tryParse(amountStr.replaceAll(',', '')) ?? 0;
  }

  // ===== HASH GENERATION =====

  String _generateHash(DateTime date, double amount, String description) {
    final input = '${date.toIso8601String()}|$amount|$description';
    return md5.convert(utf8.encode(input)).toString();
  }
}

class _TxnBlock {
  final String dateStr;
  final List<String> lines;
  _TxnBlock({required this.dateStr, required this.lines});
}
