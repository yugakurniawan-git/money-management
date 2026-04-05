import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

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

  /// Stores the last extracted lines for debug reporting
  List<String> _lastExtractedLines = [];

  /// Returns first N extracted lines for debug display
  String getDebugLines([int n = 40]) {
    final preview = _lastExtractedLines.take(n).toList();
    return preview.asMap().entries
        .map((e) => '${e.key}: [${e.value}]')
        .join('\n');
  }

  /// BCA MUTASI/SALDO column format: comma=thousands, dot=decimal
  /// Matches: 6,000.00 | 150,000.00 | 14,129,963.00 | 80,527.71
  /// Does NOT match: 150000.00 | 00000.00 | 089506585454
  static final RegExp _bcaAmount = RegExp(
    r'(\d{1,3}(?:,\d{3})+\.\d{2})',
  );

  /// Merchant name stuck after 00000.00 prefix in QR transactions
  static final RegExp _merchantPrefix = RegExp(r'00000\.00(.+)');

  /// Parse BCA bank statement PDF (rekening koran)
  /// [onStatus] optional callback for progress updates (e.g. "OCR berjalan...")
  Future<BcaPdfResult> parseBcaPdf(
    Uint8List pdfBytes,
    String accountId, {
    void Function(String)? onStatus,
  }) async {
    debugPrint('=== Starting PDF parse, ${pdfBytes.length} bytes ===');

    late PdfDocument document;
    try {
      document = PdfDocument(inputBytes: pdfBytes);
    } catch (e) {
      debugPrint('=== SYNCFUSION PDF ERROR: $e ===');
      throw Exception('Gagal membuka PDF: $e');
    }

    List<String> lines = [];
    String fullText = '';

    // Attempt 1: Syncfusion extractText()
    try {
      final allText = <String>[];
      final extractor = PdfTextExtractor(document);
      for (int i = 0; i < document.pages.count; i++) {
        allText.add(extractor.extractText(startPageIndex: i, endPageIndex: i));
      }
      fullText = allText.join('\n');
      lines = const LineSplitter().convert(fullText);
      debugPrint('=== Syncfusion extractText: ${lines.where((l) => l.trim().isNotEmpty).length} non-empty lines ===');
    } catch (e) {
      debugPrint('=== Syncfusion extractText error: $e ===');
    }

    // Attempt 2: extractTextLines()
    if (lines.where((l) => l.trim().isNotEmpty).isEmpty) {
      try {
        final extractor2 = PdfTextExtractor(document);
        final textLines = extractor2.extractTextLines(
          startPageIndex: 0,
          endPageIndex: document.pages.count - 1,
        );
        final nonEmpty = textLines.where((tl) => tl.text.trim().isNotEmpty);
        debugPrint('=== extractTextLines: ${nonEmpty.length} non-empty ===');
        if (nonEmpty.isNotEmpty) {
          lines = textLines.map((tl) => tl.text).toList();
          fullText = lines.join('\n');
        }
      } catch (e) {
        debugPrint('=== extractTextLines error: $e ===');
      }
    }

    document.dispose();

    // Attempt 3: PDF.js text layer (handles some font encodings Syncfusion can't)
    if (lines.where((l) => l.trim().isNotEmpty).isEmpty && kIsWeb) {
      try {
        if (js.context.hasProperty('pdfJsExtractText')) {
          final jsBytesList = js.JsArray.from(pdfBytes);
          final pdfJsText = await _extractWithPdfJsList(jsBytesList, 'pdfJsExtractText');
          debugPrint('=== PDF.js text layer: ${pdfJsText.trim().length} chars ===');
          if (pdfJsText.trim().isNotEmpty) {
            lines = const LineSplitter().convert(pdfJsText);
            fullText = pdfJsText;
          }
        }
      } catch (e) {
        debugPrint('=== PDF.js text layer error: $e ===');
      }
    }

    // Attempt 4: OCR via Tesseract.js (for image-based PDFs like iOS Mobile BCA)
    if (lines.where((l) => l.trim().isNotEmpty).isEmpty && kIsWeb) {
      try {
        if (js.context.hasProperty('ocrPdfPages')) {
          onStatus?.call('OCR sedang berjalan...\n(mungkin ~30 detik untuk PDF iOS)');
          debugPrint('=== Starting OCR fallback ===');
          final jsBytesList = js.JsArray.from(pdfBytes);
          final ocrText = await _extractWithPdfJsList(jsBytesList, 'ocrPdfPages');
          debugPrint('=== OCR result: ${ocrText.trim().length} chars ===');
          if (ocrText.trim().isNotEmpty) {
            final cleaned = _cleanOcrText(ocrText);
            lines = const LineSplitter().convert(cleaned);
            fullText = cleaned;
          }
        }
      } catch (e) {
        debugPrint('=== OCR error: $e ===');
      }
    }

    final nonEmptyCount = lines.where((l) => l.trim().isNotEmpty).length;
    final isInline   = _isSyncfusionInlineFormat(lines);
    final isStagger  = !isInline && _isStaggeredMobileFormat(lines);
    final isMobile   = !isInline && !isStagger && _isMobileFormat(lines);
    final formatName = isInline ? 'INLINE' : isStagger ? 'STAGGER' : isMobile ? 'MOBILE' : 'KLIKKBCA';

    // Store diagnostic + first lines for error reporting
    final diagLines = [
      'lines:$nonEmptyCount format:$formatName',
      ...lines.where((l) => l.trim().isNotEmpty).take(30),
    ];
    _lastExtractedLines = diagLines;

    final year = _detectYear(lines);
    final summary = _parseSummary(lines);

    List<TransactionModel> transactions;

    if (isInline) {
      transactions = _parseSyncfusionInlineFormat(lines, accountId);
      // False-positive INLINE detection (e.g. KlikBCA has standalone DB/CR too)
      // — fall through to structured parser if INLINE found nothing
      if (transactions.isEmpty) {
        debugPrint('=== INLINE found 0, falling back to structured parser ===');
        transactions = _parseTransactions(lines, accountId, year);
        if (transactions.isEmpty) {
          transactions = _parseWithRegex(fullText, accountId, year);
        }
      }
    } else if (isStagger) {
      transactions = _parseStaggeredMobileFormat(lines, accountId);
    } else if (isMobile) {
      transactions = _parseMobileFormat(lines, accountId);
    } else {
      transactions = _parseTransactions(lines, accountId, year);
      if (transactions.isEmpty) {
        transactions = _parseWithRegex(fullText, accountId, year);
      }
    }

    debugPrint('=== FORMAT:$formatName LINES:$nonEmptyCount TX:${transactions.length} ===');

    return BcaPdfResult(transactions: transactions, summary: summary);
  }

  /// Call a JS function(bytesList, onSuccess, onError) and return result as Future<String>
  Future<String> _extractWithPdfJsList(dynamic jsBytesList, String jsFnName) {
    final completer = Completer<String>();
    try {
      js.context.callMethod(jsFnName, [
        jsBytesList,
        js.allowInterop((String text) => completer.complete(text)),
        js.allowInterop((String err) =>
            completer.completeError(Exception('$jsFnName: $err'))),
      ]);
    } catch (e) {
      completer.completeError(e);
    }
    return completer.future;
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

  // ===== myBCA SYNCFUSION INLINE FORMAT =====
  // Syncfusion extracts each PDF text box as a separate line.
  // Amount and DB/CR are on their own separate lines.
  //
  // Block structure per transaction:
  //   PEND              ← first TX only (no date yet)
  //   TGL: 0404 QRC 014 00000.00IDM INDOMA   ← description
  //   TRANSAKSI DEBIT   ← type
  //   30,000.00         ← amount (standalone, leading space possible)
  //   DB                ← debit/credit marker (standalone!)
  //   03/04/2026        ← date of NEXT transaction (starts next block)

  /// Detect myBCA mobile INLINE format.
  /// Strong signal: standalone PEND marker (always present in myBCA mobile).
  /// Weak signal: 2+ standalone DB/CR lines (fails for single-transaction PDFs).
  bool _isSyncfusionInlineFormat(List<String> lines) {
    bool hasPend = false;
    int dbCrCount = 0;
    for (final line in lines) {
      final t = line.trim();
      if (t == 'PEND') hasPend = true;
      if (t == 'DB' || t == 'CR') dbCrCount++;
    }
    // PEND alone is definitive; also catch 2+ standalone DB/CR without PEND
    return hasPend || dbCrCount >= 2;
  }

  List<TransactionModel> _parseSyncfusionInlineFormat(
      List<String> lines, String accountId) {
    final dateRe = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');

    int year = DateTime.now().year;
    for (final line in lines) {
      final m = RegExp(r'\d{2}/\d{2}/(20\d{2})').firstMatch(line);
      if (m != null) { year = int.parse(m.group(1)!); break; }
    }

    // Group lines into blocks. Each block starts at PEND or DD/MM/YYYY.
    // Body = all lines until the next date/PEND trigger.
    final List<({DateTime? date, bool isPend, List<String> body})> blocks = [];
    var body = <String>[];
    DateTime? curDate;
    bool curIsPend = false;
    bool started = false;
    // Guard: only allow date-triggered start AFTER the table header row
    // (TANGGAL/KETERANGAN) to avoid picking up dates from the document header.
    bool seenTableHeader = false;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      // Check table header BEFORE _isSkippableLine (which also filters these words)
      if (line == 'TANGGAL' || line == 'KETERANGAN' ||
          line == 'MUTASI'  || line == 'SALDO') {
        seenTableHeader = true;
        continue;
      }
      if (_isSkippableLine(line)) continue;
      if (line == 'PEND' && started) { continue; }
      if (line.startsWith(':')) continue;
      if (line == 'Rekening') continue;
      if (_isTableEnd(line)) break;

      // PEND = start of transaction area (first TX has no date prefix)
      if (line == 'PEND' && !started) {
        started = true;
        curIsPend = true;
        curDate = null;
        body = [];
        continue;
      }

      // DD/MM/YYYY alone = start of next block, OR starts parsing when no PEND marker.
      // Only allow date-triggered start after the table header has been seen,
      // so header-area dates (e.g. PERIODE) don't prematurely start the parser.
      final dm = dateRe.firstMatch(line);
      if (dm != null && (started || seenTableHeader)) {
        if (started && (body.isNotEmpty || curIsPend)) {
          blocks.add((date: curDate, isPend: curIsPend, body: List.from(body)));
        }
        started = true;
        curDate = DateTime(int.parse(dm.group(3)!),
            int.parse(dm.group(2)!), int.parse(dm.group(1)!));
        curIsPend = false;
        body = [];
        continue;
      }

      if (!started) continue;

      body.add(line);
    }
    // Flush last block
    if (body.isNotEmpty || curIsPend) {
      blocks.add((date: curDate, isPend: curIsPend, body: List.from(body)));
    }

    debugPrint('=== Inline: ${blocks.length} blocks ===');

    final transactions = <TransactionModel>[];

    for (final block in blocks) {
      // Find amount and DB/CR from body
      double amount = 0;
      bool isDebit = true;
      bool foundDbCr = false;

      for (final bl in block.body) {
        final t = bl.trim();
        if (t == 'DB') { isDebit = true;  foundDbCr = true; continue; }
        if (t == 'CR') { isDebit = false; foundDbCr = true; continue; }
        // Standalone amount line (only a BCA amount, optional leading space)
        final am = _bcaAmount.firstMatch(t);
        if (am != null) {
          final rest = t.replaceAll(_bcaAmount, '').trim();
          if (rest.isEmpty || rest == 'DB' || rest == 'CR') {
            amount = _parseBcaAmount(am.group(1)!);
            if (rest == 'DB') { isDebit = true;  foundDbCr = true; }
            if (rest == 'CR') { isDebit = false; foundDbCr = true; }
          }
        }
      }

      if (amount <= 0) continue;

      // Override isDebit from type keyword if DB/CR marker not found
      if (!foundDbCr) {
        final bodyUpper = block.body.join(' ').toUpperCase();
        if (bodyUpper.contains('TRSF E-BANKING CR') ||
            bodyUpper.contains('KR OTOMATIS') ||
            bodyUpper.contains('BUNGA') ||
            bodyUpper.contains('SETORAN')) {
          isDebit = false;
        }
      }

      // Description = body lines that are NOT standalone amount/DB/CR
      final descLines = block.body.where((bl) {
        final t = bl.trim();
        if (t == 'DB' || t == 'CR') return false;
        final am = _bcaAmount.firstMatch(t);
        if (am != null && t.replaceAll(_bcaAmount, '').trim().isEmpty) return false;
        return true;
      }).toList();

      final desc = _buildMobileDescription(descLines);

      // Determine date
      final DateTime date;
      if (block.date != null) {
        date = block.date!;
      } else if (block.isPend) {
        date = _extractDateFromMergedRow(descLines.join(' '), year);
      } else {
        continue;
      }

      final type = isDebit ? 'debit' : 'credit';
      final finalDesc = desc.isNotEmpty
          ? desc
          : (isDebit ? 'TRANSAKSI DEBIT' : 'TRSF E-BANKING CR');

      transactions.add(_buildTx(
          date, amount, type, finalDesc, block.body.join(' '), accountId));
      debugPrint('INLINE TX: $date | $type | $amount | $finalDesc');
    }

    return transactions;
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
  /// Syncfusion merges all text elements at the same y-coordinate into ONE line.
  /// Each transaction is a single "main row" followed by one optional type/desc line:
  ///
  ///   PEND    TGL: 0404 QRC 014 00000.00IDM INDOMA    30,000.00 DB  ← TX1 (all in 1 line)
  ///   TRANSAKSI DEBIT                                                 ← TX1 type (optional)
  ///   03/04/2026    TGL: 0403 QR  014 00000.00TOKO KOPI    29,000.00 DB  ← TX2
  ///   TRANSAKSI DEBIT
  ///   03/04/2026    0304/FTSCY/WS95271 10000.00HILDA FITRI ANGUL    10,000.00 CR
  ///   TRSF E-BANKING CR
  ///   02/04/2026    089506585454    100,000.00 DB
  ///   TARIKAN ATM 02/04
  ///
  /// Each main row contains: date (or PEND) + desc_middle + BCA_amount DB|CR
  List<TransactionModel> _parseStaggeredMobileFormat(
      List<String> lines, String accountId) {
    // Detect year from any full date in the lines
    int year = DateTime.now().year;
    for (final line in lines) {
      final m = RegExp(r'\d{2}/\d{2}/(20\d{2})').firstMatch(line);
      if (m != null) { year = int.parse(m.group(1)!); break; }
    }

    final pendRowRe  = RegExp(r'^PEND\s+(.+)$', caseSensitive: false);
    final dateRowRe  = RegExp(r'^(\d{2})/(\d{2})/(\d{4})\s+(.+)$');

    final transactions = <TransactionModel>[];
    bool inArea = false;

    // State for the current "pending" main row (waiting for optional type line)
    String? pendingRest;       // everything after stripping PEND / date prefix
    DateTime? pendingDate;     // null means extract from TGL: inside the rest

    // Flush a pending row into a transaction, using [continuation] as extra desc/type
    void flush(String? continuation) {
      if (pendingRest == null) return;
      final rest = pendingRest!;

      // ── Find the LAST BCA amount in rest ──
      final allAmounts = _bcaAmount.allMatches(rest).toList();
      if (allAmounts.isEmpty) { pendingRest = null; return; }

      final lastM = allAmounts.last;
      final amount = _parseBcaAmount(lastM.group(1)!);
      if (amount <= 0) { pendingRest = null; return; }

      // ── Type: DB/CR marker immediately after the last amount ──
      final afterAmt = rest.substring(lastM.end).trim();
      bool isDebit = !afterAmt.startsWith('CR');

      // ── Override type from continuation line keywords ──
      if (continuation != null) {
        final up = continuation.toUpperCase();
        if (up.contains('TRSF E-BANKING CR') || up.contains('KR OTOMATIS') ||
            up.contains('BUNGA') || up.contains('SETORAN')) {
          isDebit = false;
        } else if (up.contains('TRSF E-BANKING DB') || up.contains('TARIKAN ATM') ||
            up.contains('TRANSAKSI DEBIT') || up.contains('BIAYA ADM')) {
          isDebit = true;
        }
      }

      // ── Description: everything before the last amount ──
      final descPart = rest.substring(0, lastM.start).trim();
      final descLines = <String>[if (descPart.isNotEmpty) descPart,
                                  if (continuation != null) continuation];
      final desc = _buildMobileDescription(descLines);

      // ── Date: from explicit date or from TGL:/reference in desc ──
      final date = pendingDate ?? _extractDateFromMergedRow(descPart, year);

      final type    = isDebit ? 'debit' : 'credit';
      final finalDesc = desc.isNotEmpty ? desc : (isDebit ? 'TRANSAKSI DEBIT' : 'TRSF E-BANKING CR');

      transactions.add(_buildTx(date, amount, type, finalDesc,
          '$descPart ${continuation ?? ''}', accountId));
      debugPrint('MERGED TX: $date | $type | $amount | $finalDesc');

      pendingRest = null;
      pendingDate = null;
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (_isSkippableLine(line)) continue;
      if (_isTableEnd(line)) { flush(null); break; }

      // ── PEND main row: "PEND    desc_middle    amount DB|CR" ──
      final pendMatch = pendRowRe.firstMatch(line);
      if (pendMatch != null) {
        flush(null);
        pendingRest = pendMatch.group(1)!;
        pendingDate = null;
        inArea = true;
        continue;
      }

      // ── Date main row: "DD/MM/YYYY    desc_middle    amount DB|CR" ──
      final dateMatch = dateRowRe.firstMatch(line);
      if (dateMatch != null) {
        flush(null);
        pendingDate = DateTime(int.parse(dateMatch.group(3)!),
            int.parse(dateMatch.group(2)!), int.parse(dateMatch.group(1)!));
        pendingRest = dateMatch.group(4)!;
        inArea = true;
        continue;
      }

      if (!inArea) continue;

      // ── Continuation / type line: flush pending row with this as extra info ──
      if (pendingRest != null) {
        flush(line);
      }
    }

    flush(null); // final flush
    debugPrint('=== Staggered merged: ${transactions.length} transactions ===');
    return transactions;
  }

  /// Extract date for a PEND row (no explicit date prefix) from the description.
  /// Looks for "TGL: DDMM" or a reference code "DDMM/..." prefix.
  DateTime _extractDateFromMergedRow(String descPart, int year) {
    // "TGL: 0404 ..." → day=04, month=04
    final tglM = RegExp(r'TGL\s*:\s*(\d{2})(\d{2})', caseSensitive: false)
        .firstMatch(descPart);
    if (tglM != null) {
      final day   = int.tryParse(tglM.group(1)!);
      final month = int.tryParse(tglM.group(2)!);
      if (day != null && month != null && day >= 1 && day <= 31 && month >= 1 && month <= 12) {
        return DateTime(year, month, day);
      }
    }
    // "0404/FTSCY/..." → day=04, month=04
    final refM = RegExp(r'^(\d{2})(\d{2})/').firstMatch(descPart.trim());
    if (refM != null) {
      final day   = int.tryParse(refM.group(1)!);
      final month = int.tryParse(refM.group(2)!);
      if (day != null && month != null && day >= 1 && day <= 31 && month >= 1 && month <= 12) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.now();
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

      // Check for transaction start: DD/MM optionally followed by /year-fragment
      // OCR of iOS PDFs may produce partial years like "31/03/2" or "31/03/20"
      // because the date column is visually truncated in the PDF
      final dateMatch = RegExp(r'^(\d{2}/\d{2})(?:/[^\s]*)?\s+(.+)').firstMatch(line);
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

  /// Fix common OCR artifacts in BCA statement text.
  /// Tesseract often misreads '/' as '7', '1', or 'l' in date fields,
  /// and confuses ',' and '.' in amounts.
  String _cleanOcrText(String raw) {
    final lines = const LineSplitter().convert(raw);
    final out = <String>[];

    for (final line in lines) {
      var l = line;

      // Fix date patterns: OCR often garbles DD/MM/YYYY
      // e.g. "31/0372026" → "31/03/2026", "3l/03/2026" → "31/03/2026"
      // Pattern: two digits, slash-or-garble, two digits, slash-or-garble, four digits
      l = l.replaceAllMapped(
        RegExp(r'(\d{2})[/\\l1|](\d{2})[/\\l1|7](\d{4})'),
        (m) => '${m[1]}/${m[2]}/${m[3]}',
      );

      // Fix partial dates at line start: "31/0372..." → try to recover "31/03/2..."
      l = l.replaceAllMapped(
        RegExp(r'^(\d{2}/\d{2})7(\d)'),
        (m) => '${m[1]}/${m[2]}',
      );

      // Fix common OCR char substitutions in amounts: 'O'→'0', 'l'→'1', 'S'→'5'
      // Only in number-like sequences (digits + commas + dots)
      l = l.replaceAllMapped(
        RegExp(r'(\d+[,.]?\d*)[Ol](\d)'),
        (m) => '${m[1]}0${m[2]}',
      );

      // "DB" sometimes OCR'd as "D8" or "D6" or "08"
      l = l.replaceAll(RegExp(r'\bD[B8b6]\b'), 'DB');
      // "CR" sometimes OCR'd as "GR" or "C R"
      l = l.replaceAll(RegExp(r'\b[CG]R\b'), 'CR');

      out.add(l);
    }
    return out.join('\n');
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
