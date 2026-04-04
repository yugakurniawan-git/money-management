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

    List<TransactionModel> transactions;

    // Detect format — staggered check must come before plain mobile check
    if (_isStaggeredMobileFormat(lines)) {
      // Syncfusion merges same-y text: "03/04/2026    29,000.00 DB" on one line
      debugPrint('=== Detected myBCA STAGGERED MOBILE format (Syncfusion merged) ===');
      transactions = _parseStaggeredMobileFormat(lines, accountId);
    } else if (_isMobileFormat(lines)) {
      // pdfminer-style: standalone DD/MM/YYYY dates + trailing MUTASI block
      debugPrint('=== Detected myBCA MOBILE format (column-separated) ===');
      transactions = _parseMobileFormat(lines, accountId);
    } else {
      // KlikBCA desktop / structured line-by-line format
      transactions = _parseTransactions(lines, accountId, year);

      // Fallback: regex-based parsing on full text
      if (transactions.isEmpty) {
        debugPrint('=== Structured parsing found 0 transactions, trying regex fallback ===');
        transactions = _parseWithRegex(fullText, accountId, year);
      }
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

  // ===== myBCA STAGGERED MOBILE FORMAT (Syncfusion output) =====

  /// Syncfusion merges text elements at the same y-coordinate into one line.
  /// In myBCA mobile PDFs the date column (x≈188) and the next-transaction
  /// amount column (x≈2531) share the same y, so Syncfusion produces lines
  /// like "03/04/2026    29,000.00 DB".  We detect this by looking for at
  /// least two lines that contain both a full DD/MM/YYYY date and a BCA amount.
  bool _isStaggeredMobileFormat(List<String> lines) {
    final re = RegExp(r'\d{2}/\d{2}/\d{4}.+\d{1,3}(?:,\d{3})+\.\d{2}');
    int count = 0;
    for (final line in lines) {
      if (re.hasMatch(line.trim())) {
        if (++count >= 2) return true;
      }
    }
    return false;
  }

  /// Parse myBCA mobile PDF as extracted by Syncfusion.
  ///
  /// Layout (staggered columns merged by Syncfusion):
  ///   PEND    30,000.00 DB          ← TX1 amount (no date on this row)
  ///   TGL: 0404 QRC 014 00000.00IDM INDOMA   ← TX1 description
  ///   TRANSAKSI DEBIT
  ///   03/04/2026    29,000.00 DB    ← TX1 date  +  TX2 amount (same y!)
  ///   TGL: 0403 TOKO KOPI ...       ← TX2 description
  ///   03/04/2026    18,000.00 DB    ← TX2 date  +  TX3 amount
  ///   …
  ///   01/04/2026    5,000.00 DB     ← TX(n-1) date  +  TXn amount
  ///   TXn description
  ///   01/04/2026                    ← TXn date (date-only, no next amount)
  ///
  /// Mapping:
  ///   TX1  : amount = firstAmount,    date = pairs[0].date
  ///   TXk  : amount = pairs[k-2].amount, date = pairs[k-1].date  (k ≥ 2)
  ///   TXlast: amount = pairs[n-2].amount, date = lastDateOnly (or pairs[n-1].date)
  List<TransactionModel> _parseStaggeredMobileFormat(
      List<String> lines, String accountId) {
    final staggeredRe = RegExp(r'^(\d{2})/(\d{2})/(\d{4})\s+(.+)$');
    final dateOnlyRe = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');

    double? firstAmount;
    bool firstIsDebit = true;
    bool seenPend = false;

    final List<({DateTime date, double amount, bool isDebit})> pairs = [];
    DateTime? lastDateOnly;

    final List<List<String>> descBlocks = [];
    var currentDesc = <String>[];

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      // ── Phase 1: find the PEND line that marks transaction area start ──
      if (!seenPend) {
        if (line.startsWith('PEND')) {
          final m = _bcaAmount.firstMatch(line);
          if (m != null) {
            firstAmount = _parseBcaAmount(m.group(1)!);
            firstIsDebit = line.contains('DB');
          }
          seenPend = true;
        }
        continue; // skip everything until PEND found
      }

      // ── Phase 2: processing inside the transaction area ──

      if (_isSkippableLine(line)) continue;
      if (line == 'PEND' || line == 'SALDO' ||
          line == 'TANGGAL' || line == 'KETERANGAN') { continue; }
      if (line == 'Rekening') continue;
      if (line.startsWith(':')) continue;
      if (_isTableEnd(line)) break;

      // If firstAmount was not on the PEND line, grab it from the very next
      // amount-only line before any date-amount pairs appear.
      if (firstAmount == null) {
        final m = _bcaAmount.firstMatch(line);
        if (m != null) {
          firstAmount = _parseBcaAmount(m.group(1)!);
          firstIsDebit = line.contains('DB');
          continue;
        }
      }

      // Staggered line: "DD/MM/YYYY    amount DB|CR"
      final sm = staggeredRe.firstMatch(line);
      if (sm != null) {
        final date = DateTime(
          int.parse(sm.group(3)!),
          int.parse(sm.group(2)!),
          int.parse(sm.group(1)!),
        );
        final rest = sm.group(4)!;
        final am = _bcaAmount.firstMatch(rest);
        if (am != null) {
          pairs.add((
            date: date,
            amount: _parseBcaAmount(am.group(1)!),
            isDebit: rest.contains('DB'),
          ));
          descBlocks.add(List.from(currentDesc));
          currentDesc = [];
        } else {
          // Date present but no following amount → last transaction's date
          lastDateOnly = date;
          descBlocks.add(List.from(currentDesc));
          currentDesc = [];
        }
        continue;
      }

      // Standalone date line (last transaction's date)
      final dm = dateOnlyRe.firstMatch(line);
      if (dm != null) {
        lastDateOnly = DateTime(
          int.parse(dm.group(3)!),
          int.parse(dm.group(2)!),
          int.parse(dm.group(1)!),
        );
        descBlocks.add(List.from(currentDesc));
        currentDesc = [];
        continue;
      }

      // Ordinary description line
      currentDesc.add(line);
    }

    // Flush any trailing description block
    if (currentDesc.isNotEmpty) descBlocks.add(List.from(currentDesc));

    debugPrint(
        '=== Staggered: firstAmount=$firstAmount, ${pairs.length} pairs, ${descBlocks.length} descBlocks ===');

    if (firstAmount == null || pairs.isEmpty) return [];

    final transactions = <TransactionModel>[];
    final n = pairs.length; // = total transactions − 1

    // TX1
    {
      final descLines = descBlocks.isNotEmpty ? descBlocks[0] : <String>[];
      final desc = _buildMobileDescription(descLines);
      final type = firstIsDebit ? 'debit' : 'credit';
      transactions.add(_buildTx(
        pairs[0].date,
        firstAmount,
        type,
        desc.isNotEmpty ? desc : (firstIsDebit ? 'TRANSAKSI DEBIT' : 'TRSF E-BANKING CR'),
        descLines.join(' '),
        accountId,
      ));
      debugPrint('STAGGERED TX1: ${pairs[0].date} | $type | $firstAmount | $desc');
    }

    // TX2 … TX(n+1)
    for (int k = 1; k <= n; k++) {
      final pair = pairs[k - 1];
      final DateTime date;
      if (k < n) {
        date = pairs[k].date;
      } else {
        // Last transaction: date from standalone date line, or reuse last pair's date
        date = lastDateOnly ?? pairs[n - 1].date;
      }

      final descLines = k < descBlocks.length ? descBlocks[k] : <String>[];
      final desc = _buildMobileDescription(descLines);
      final type = pair.isDebit ? 'debit' : 'credit';

      if (pair.amount > 0) {
        transactions.add(_buildTx(
          date,
          pair.amount,
          type,
          desc.isNotEmpty ? desc : (pair.isDebit ? 'TRANSAKSI DEBIT' : 'TRSF E-BANKING CR'),
          descLines.join(' '),
          accountId,
        ));
        debugPrint('STAGGERED TX${k + 1}: $date | $type | ${pair.amount} | $desc');
      }
    }

    return transactions;
  }

  /// Build a TransactionModel from parsed fields.
  TransactionModel _buildTx(
    DateTime date,
    double amount,
    String type,
    String description,
    String rawDescription,
    String accountId,
  ) {
    final hash = _generateHash(date, amount, description);
    return TransactionModel(
      id: _uuid.v4(),
      accountId: accountId,
      amount: amount,
      description: description,
      rawDescription: rawDescription,
      categoryId: '',
      transactionType: type,
      transactionDate: date,
      balanceAfter: 0,
      importHash: hash,
      createdAt: DateTime.now(),
    );
  }

  // ===== myBCA MOBILE FORMAT DETECTION (column-separated / pdfminer-style) =====

  /// Returns true when standalone DD/MM/YYYY lines are found (myBCA mobile export)
  bool _isMobileFormat(List<String> lines) {
    int count = 0;
    final fullDateRe = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    for (final line in lines) {
      if (fullDateRe.hasMatch(line.trim())) {
        count++;
        if (count >= 2) return true;
      }
    }
    return false;
  }

  // ===== myBCA MOBILE FORMAT PARSER =====

  /// Parse the myBCA mobile export PDF where:
  ///  - Each transaction's description/type lines come BEFORE the date
  ///  - Date appears as a standalone DD/MM/YYYY line
  ///  - All amounts are collected in a MUTASI column at the end
  List<TransactionModel> _parseMobileFormat(
      List<String> lines, String accountId) {
    // ── Step 1: locate the trailing MUTASI amount block ────────────────────
    // The last occurrence of a standalone "MUTASI" line that is followed
    // by BCA-formatted amount lines marks the start of the amount column.
    int mutasiIdx = -1;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (lines[i].trim() == 'MUTASI') {
        bool hasAmounts = false;
        for (int j = i + 1; j < lines.length && j < i + 10; j++) {
          if (_bcaAmount.hasMatch(lines[j])) {
            hasAmounts = true;
            break;
          }
        }
        if (hasAmounts) {
          mutasiIdx = i;
          break;
        }
      }
    }

    // ── Step 2: extract (amount, isDebit) pairs from the MUTASI block ──────
    final amounts = <_MobileAmount>[];
    if (mutasiIdx >= 0) {
      for (int i = mutasiIdx + 1; i < lines.length; i++) {
        final line = lines[i].trim();
        // Skip SALDO column header if present
        if (line == 'SALDO') continue;
        final m = RegExp(r'(\d{1,3}(?:,\d{3})+\.\d{2})\s*(DB|CR)?')
            .firstMatch(line);
        if (m != null) {
          final amount = _parseBcaAmount(m.group(1)!);
          if (amount > 0) {
            amounts.add(_MobileAmount(
              amount: amount,
              isDebit: (m.group(2) ?? 'DB') == 'DB',
            ));
          }
        }
      }
    }
    debugPrint('=== Mobile: found ${amounts.length} amounts in MUTASI block ===');

    // ── Step 3: parse description blocks from the left/keterangan section ──
    final descLines =
        mutasiIdx >= 0 ? lines.sublist(0, mutasiIdx) : lines;

    final fullDateRe = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
    final blocks = <_MobileBlock>[];
    _MobileBlock? cur;
    DateTime? lastSeenDate;

    for (final raw in descLines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (_isSkippableLine(line)) continue;
      // Skip column header noise for this format
      if (line == 'PEND' || line == 'MUTASI' || line == 'SALDO') continue;
      if (line == 'TANGGAL' || line == 'KETERANGAN') continue;
      // Skip standalone partial-header words
      if (line == 'Rekening') continue;
      // Skip header value lines (colon-prefixed: ": YUGA KURNIAWAN", ": IDR", etc.)
      if (line.startsWith(':')) continue;

      final dateMatch = fullDateRe.firstMatch(line);
      if (dateMatch != null) {
        // This date closes the current block
        lastSeenDate = DateTime(
          int.parse(dateMatch.group(3)!),
          int.parse(dateMatch.group(2)!),
          int.parse(dateMatch.group(1)!),
        );
        if (cur != null) {
          cur.date = lastSeenDate;
          blocks.add(cur);
          cur = null;
        }
      } else {
        // Accumulate description lines
        cur ??= _MobileBlock();
        cur.lines.add(line);
      }
    }
    // Flush last block (no closing date line after the final transaction)
    if (cur != null && cur.lines.isNotEmpty) {
      // Try to extract date from reference code (e.g. 0204/FTSCY → 02/04)
      cur.date = _extractDateFromReference(cur.lines, lastSeenDate);
      if (cur.date != null) blocks.add(cur);
    }
    debugPrint('=== Mobile: found ${blocks.length} transaction blocks ===');

    // ── Step 4: zip blocks with amounts to build transactions ───────────────
    final transactions = <TransactionModel>[];
    final count = blocks.length < amounts.length ? blocks.length : amounts.length;

    for (int i = 0; i < count; i++) {
      final block = blocks[i];
      final amt = amounts[i];
      if (block.date == null || amt.amount <= 0) continue;

      final description = _buildMobileDescription(block.lines);
      if (description.isEmpty) continue;

      // Determine debit/credit from explicit keywords first, fall back to DB/CR marker
      var type = amt.isDebit ? 'debit' : 'credit';
      final upper = block.lines.join(' ').toUpperCase();
      if (upper.contains('TRANSAKSI DEBIT') ||
          upper.contains('TARIKAN ATM') ||
          upper.contains('BIAYA ADM')) {
        type = 'debit';
      } else if (upper.contains('TRSF E-BANKING CR') ||
          upper.contains('KR OTOMATIS') ||
          upper.contains('SETORAN') ||
          upper.contains('BUNGA')) {
        type = 'credit';
      }

      final hash = _generateHash(block.date!, amt.amount, description);
      transactions.add(TransactionModel(
        id: _uuid.v4(),
        accountId: accountId,
        amount: amt.amount,
        description: description,
        rawDescription: block.lines.join(' '),
        categoryId: '',
        transactionType: type,
        transactionDate: block.date!,
        balanceAfter: 0,
        importHash: hash,
        createdAt: DateTime.now(),
      ));
      debugPrint(
          'MOBILE TX: ${block.date} | $type | ${amt.amount} | $description');
    }

    return transactions;
  }

  /// Try to extract a date from lines like "0204/FTSCY/WS..." (DDMM prefix)
  /// or fall back to [fallback].
  DateTime? _extractDateFromReference(List<String> lines, DateTime? fallback) {
    final now = DateTime.now();
    final year = fallback?.year ?? now.year;
    for (final line in lines) {
      // Reference code: 0204/FTSCY/WS95031 → day=02, month=04
      final m = RegExp(r'^(\d{2})(\d{2})/').firstMatch(line.trim());
      if (m != null) {
        final day = int.tryParse(m.group(1)!);
        final month = int.tryParse(m.group(2)!);
        if (day != null && month != null &&
            day >= 1 && day <= 31 && month >= 1 && month <= 12) {
          return DateTime(year, month, day);
        }
      }
    }
    return fallback;
  }

  /// Build description from mobile format lines (skips type-indicator lines)
  String _buildMobileDescription(List<String> rawLines) {
    final parts = <String>[];
    for (final line in rawLines) {
      final l = line.trim();
      if (l.isEmpty) continue;

      // Transaction-type indicator lines — use as fallback description only
      if (l.startsWith('TRANSAKSI DEBIT') ||
          l.startsWith('TRSF E-BANKING CR') ||
          l.startsWith('TRSF E-BANKING DB') ||
          l.startsWith('BIAYA ADM')) {
        if (parts.isEmpty) parts.add(l);
        continue;
      }
      // TARIKAN ATM may have inline date: strip it
      if (l.startsWith('TARIKAN ATM')) {
        var cleaned = l.replaceAll(RegExp(r'\s+\d{2}/\d{2}$'), '').trim();
        if (parts.isEmpty) parts.add(cleaned);
        continue;
      }

      // Reference code lines: "0304/FTSCY/WS95271   10000.00HILDA FITRI ANGUL"
      // → extract name after raw amount (if present)
      if (RegExp(r'^\d{4}/\w+/\w+').hasMatch(l)) {
        final nameMatch = RegExp(r'\d+\.00(.+)').firstMatch(l);
        if (nameMatch != null) {
          final name = nameMatch.group(1)!.trim();
          if (name.isNotEmpty) parts.add(name);
        }
        continue;
      }

      // Skip phone numbers
      if (RegExp(r'^\d{10,}$').hasMatch(l)) continue;

      // Skip masked phones: Q0895XXXXXX54
      if (RegExp(r'^Q\d+X+\d*').hasMatch(l)) continue;

      // TGL: 0404  QRC 014  00000.00MERCHANT → extract merchant
      if (RegExp(r'^TGL\s*:', caseSensitive: false).hasMatch(l)) {
        final merchantMatch = _merchantPrefix.firstMatch(l);
        if (merchantMatch != null) {
          parts.add(merchantMatch.group(1)!.trim());
        }
        continue;
      }

      // Amounts only: skip
      final lineWithoutAmounts = l
          .replaceAll(_bcaAmount, '')
          .replaceAll(RegExp(r'\bDB\b|\bCR\b'), '')
          .trim();
      if (lineWithoutAmounts.isEmpty) continue;

      // Transfer with embedded raw amount: 10000.00HILDA FITRI → extract name
      final nameAfterAmount = RegExp(r'\d+\.00(.+)').firstMatch(l);
      if (nameAfterAmount != null) {
        parts.add(nameAfterAmount.group(1)!.trim());
        continue;
      }

      // Keep lines with letters (names, merchant names, etc.)
      if (RegExp(r'[A-Za-z]{2,}').hasMatch(l)) {
        var cleaned = l.replaceAll(_bcaAmount, '').trim();
        cleaned = cleaned.replaceAll(RegExp(r'\bDB\b|\bCR\b'), '').trim();
        cleaned = cleaned.replaceAll(RegExp(r'\b\d{3,}\.00\b'), '').trim();
        if (cleaned.isNotEmpty) parts.add(cleaned);
      }
    }

    return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
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

class _MobileBlock {
  List<String> lines = [];
  DateTime? date;
}

class _MobileAmount {
  final double amount;
  final bool isDebit;
  _MobileAmount({required this.amount, required this.isDebit});
}
