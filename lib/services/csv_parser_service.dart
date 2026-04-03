import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import 'pdf_parser_service.dart'; // reuse BcaPdfSummary

/// Result from parsing BCA CSV
class BcaCsvResult {
  final List<TransactionModel> transactions;
  final BcaPdfSummary summary;

  BcaCsvResult({required this.transactions, required this.summary});
}

class CsvParserService {
  final _uuid = const Uuid();

  /// Parse BCA CSV export file (myBCA / KlikBCA format)
  BcaCsvResult parseBcaCsv(String csvContent, String accountId) {
    final lines = const LineSplitter().convert(csvContent);
    final transactions = <TransactionModel>[];

    // Parse header info
    String noRekening = '';
    for (final line in lines) {
      if (line.contains('Account No') && line.contains('=')) {
        noRekening = line.split(',').last.trim().replaceAll("'", '');
      }
    }

    // Find data start (after "Date,Description,..." header)
    int dataStartIndex = _findDataStartIndex(lines);
    if (dataStartIndex == -1) {
      debugPrint('=== CSV: Could not find data header, trying direct parse ===');
      final directResult = _parseDirectCsv(csvContent, accountId);
      return BcaCsvResult(
        transactions: directResult,
        summary: BcaPdfSummary(noRekening: noRekening),
      );
    }

    debugPrint('=== CSV: Data starts at line $dataStartIndex ===');

    // Parse data rows
    for (int i = dataStartIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Stop at footer summary
      if (line.startsWith('Starting Balance') ||
          line.startsWith('Saldo Awal') ||
          line.startsWith('Credit') ||
          line.startsWith('Debet') ||
          line.startsWith('Ending Balance')) {
        break;
      }

      final txn = _parseBcaLine(line, accountId);
      if (txn != null) {
        transactions.add(txn);
      }
    }

    // Parse footer summary
    final summary = _parseCsvSummary(lines, noRekening);

    debugPrint('=== CSV: Parsed ${transactions.length} transactions ===');

    return BcaCsvResult(transactions: transactions, summary: summary);
  }

  /// Find the header row index
  int _findDataStartIndex(List<String> lines) {
    for (int i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      if ((lower.contains('date') && lower.contains('description')) ||
          (lower.contains('tanggal') && lower.contains('keterangan')) ||
          lower.contains('tgl transaksi')) {
        return i + 1;
      }
    }
    return -1;
  }

  /// Parse a single CSV data line
  TransactionModel? _parseBcaLine(String line, String accountId) {
    try {
      final parsed = const CsvToListConverter().convert(line);
      if (parsed.isEmpty || parsed[0].length < 4) return null;

      final row = parsed[0];
      final dateStr = row[0].toString().trim();
      final rawDescription = row[1].toString().trim();
      final amountStr = row.length > 3 ? row[3].toString().trim() : '0';
      final typeStr = row.length > 4 ? row[4].toString().trim() : '';
      final balanceStr = row.length > 5 ? row[5].toString().trim() : '0';

      final date = _parseDate(dateStr);
      if (date == null) return null;

      final amount = _parseAmount(amountStr);
      if (amount <= 0) return null;

      final balance = _parseAmount(balanceStr);

      // Determine transaction type from CR/DB column
      String txnType;
      if (typeStr.toUpperCase() == 'CR') {
        txnType = 'credit';
      } else if (typeStr.toUpperCase() == 'DB') {
        txnType = 'debit';
      } else {
        // Fallback: detect from description
        txnType = _detectTypeFromDescription(rawDescription);
      }

      // Clean the description
      final description = _cleanDescription(rawDescription);
      if (description.isEmpty) return null;

      final hash = _generateHash(date, amount, description);

      debugPrint(
          'CSV TX: ${date.day}/${date.month} | $txnType | $amount | $description');

      return TransactionModel(
        id: _uuid.v4(),
        accountId: accountId,
        amount: amount.abs(),
        description: description,
        rawDescription: rawDescription,
        categoryId: '',
        transactionType: txnType,
        transactionDate: date,
        balanceAfter: balance,
        importHash: hash,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('CSV parse error: $e for line: $line');
      return null;
    }
  }

  /// Detect transaction type from description keywords
  String _detectTypeFromDescription(String desc) {
    final upper = desc.toUpperCase();
    if (upper.contains('CR') && !upper.contains('DB')) return 'credit';
    if (upper.contains('KR OTOMATIS')) return 'credit';
    if (upper.contains('BUNGA') || upper.contains('INTEREST')) return 'credit';
    if (upper.contains('BI-FAST CR')) return 'credit';
    return 'debit';
  }

  /// Clean BCA CSV description — remove reference codes, raw amounts, noise
  String _cleanDescription(String desc) {
    var cleaned = desc;

    // Remove BCA ref codes: DDMM/FTXXX/WSYYYYY (with optional service code stuck)
    // e.g., 0803/FTFVA/WS9503170001/ or 0103/FTSCY/WS95031
    cleaned = cleaned.replaceAll(
        RegExp(r'\d{4}/FT\w+/WS\d{5}(?:\d{5}/)?'), '');

    // Remove service code prefix (keep the service name):
    // 70001/GOPAY TOPUP → GOPAY TOPUP
    // 39888/MY TELKOMSEL → MY TELKOMSEL
    // 39358/OVO → OVO
    // 39010/DANA → DANA
    cleaned = cleaned.replaceAll(RegExp(r'\b\d{5}/'), '');

    // Remove 00000.00 prefix stuck to merchant name: 00000.00PREMIERE B → PREMIERE B
    cleaned = cleaned.replaceAll(RegExp(r'00000\.00'), '');

    // Remove raw amounts stuck to names: 20000.00RINI → RINI
    // (digits.00 immediately followed by a letter)
    cleaned = cleaned.replaceAll(RegExp(r'\d+\.00(?=[A-Za-z])'), '');

    // Remove standalone raw amounts (5+ digits.00)
    cleaned = cleaned.replaceAll(RegExp(r'\b\d{5,}\.00\b'), '');

    // Remove TGL: DDMM date references
    cleaned = cleaned.replaceAll(RegExp(r'TGL:\s*\d{4}\s*'), '');

    // Remove QR codes: QR  014, QRC 014, QR  914
    cleaned = cleaned.replaceAll(RegExp(r'QR\s*C?\s*\d{3}\s*'), '');

    // Remove phone numbers (10+ digits starting with 0)
    cleaned = cleaned.replaceAll(RegExp(r'\b0\d{9,}\b'), '');

    // Remove other long digit sequences (like 00041031844)
    cleaned = cleaned.replaceAll(RegExp(r'\b\d{8,}\b'), '');

    // Remove branch code at start: '0000, '0938
    cleaned = cleaned.replaceAll(RegExp(r"^'\d{4}\s*"), '');

    // Remove standalone dashes
    cleaned = cleaned.replaceAll(RegExp(r'\s+-(\s|$)'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'(^|\s)-\s'), ' ');

    // Remove trailing dash stuck to text: TELKOMSEL- → TELKOMSEL
    cleaned = cleaned.replaceAll(RegExp(r'-$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'-\s'), ' ');

    // Clean multiple spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    // Remove trailing comma if any
    if (cleaned.endsWith(',')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }

    return cleaned;
  }

  /// Parse CSV footer summary
  BcaPdfSummary _parseCsvSummary(List<String> lines, String noRekening) {
    double saldoAwal = 0, saldoAkhir = 0, mutasiCr = 0, mutasiDb = 0;
    int countCr = 0, countDb = 0;
    String periode = '';

    // Count CR/DB from transactions
    for (final line in lines) {
      if (line.contains(',CR,')) countCr++;
      if (line.contains(',DB,')) countDb++;
    }

    // Parse footer
    for (final line in lines) {
      final trimmed = line.trim();

      // PERIODE info from header
      if (trimmed.contains('PERIODE') && trimmed.contains(':')) {
        periode = trimmed.split(':').last.trim();
      }

      // Starting Balance,=,77040.71
      if (trimmed.startsWith('Starting Balance') ||
          trimmed.startsWith('Saldo Awal')) {
        final match = RegExp(r'[\d.]+$').firstMatch(trimmed);
        if (match != null) {
          saldoAwal = double.tryParse(match.group(0)!) ?? 0;
        }
      }

      // Credit,=,25776584.00
      if (trimmed.startsWith('Credit') && trimmed.contains('=')) {
        final match = RegExp(r'[\d.]+$').firstMatch(trimmed);
        if (match != null) {
          mutasiCr = double.tryParse(match.group(0)!) ?? 0;
        }
      }

      // Debet,=,25736651.00
      if (trimmed.startsWith('Debet') && trimmed.contains('=')) {
        final match = RegExp(r'[\d.]+$').firstMatch(trimmed);
        if (match != null) {
          mutasiDb = double.tryParse(match.group(0)!) ?? 0;
        }
      }

      // Ending Balance,=,116973.71
      if (trimmed.startsWith('Ending Balance') ||
          trimmed.startsWith('Saldo Akhir')) {
        final match = RegExp(r'[\d.]+$').firstMatch(trimmed);
        if (match != null) {
          saldoAkhir = double.tryParse(match.group(0)!) ?? 0;
        }
      }
    }

    // Try to detect periode from dates
    if (periode.isEmpty) {
      for (final line in lines) {
        final dateMatch =
            RegExp(r"'?(\d{2})/(\d{2})/(\d{4})").firstMatch(line);
        if (dateMatch != null) {
          final month = int.tryParse(dateMatch.group(2)!) ?? 0;
          final year = dateMatch.group(3)!;
          final monthNames = [
            '',
            'JANUARI',
            'FEBRUARI',
            'MARET',
            'APRIL',
            'MEI',
            'JUNI',
            'JULI',
            'AGUSTUS',
            'SEPTEMBER',
            'OKTOBER',
            'NOVEMBER',
            'DESEMBER'
          ];
          if (month >= 1 && month <= 12) {
            periode = '${monthNames[month]} $year';
          }
          break;
        }
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

  /// Fallback: parse full CSV content directly
  List<TransactionModel> _parseDirectCsv(
      String csvContent, String accountId) {
    final rows = const CsvToListConverter().convert(csvContent);
    if (rows.length < 2) return [];

    final transactions = <TransactionModel>[];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 4) continue;

      final dateStr = row[0].toString().trim();
      final rawDescription = row[1].toString().trim();
      final amountStr = row.length > 3 ? row[3].toString().trim() : '0';
      final typeStr = row.length > 4 ? row[4].toString().trim() : '';
      final balanceStr = row.length > 5 ? row[5].toString().trim() : '0';

      final date = _parseDate(dateStr);
      if (date == null) continue;

      final amount = _parseAmount(amountStr);
      if (amount <= 0) continue;
      final balance = _parseAmount(balanceStr);

      String txnType;
      if (typeStr.toUpperCase() == 'CR') {
        txnType = 'credit';
      } else if (typeStr.toUpperCase() == 'DB') {
        txnType = 'debit';
      } else {
        txnType = _detectTypeFromDescription(rawDescription);
      }

      final description = _cleanDescription(rawDescription);
      if (description.isEmpty) continue;

      final hash = _generateHash(date, amount, description);

      transactions.add(TransactionModel(
        id: _uuid.v4(),
        accountId: accountId,
        amount: amount.abs(),
        description: description,
        rawDescription: rawDescription,
        categoryId: '',
        transactionType: txnType,
        transactionDate: date,
        balanceAfter: balance,
        importHash: hash,
        createdAt: DateTime.now(),
      ));
    }

    return transactions;
  }

  /// Parse date string (handles leading quote from BCA CSV)
  DateTime? _parseDate(String dateStr) {
    // Remove leading quote: '01/03/2026 → 01/03/2026
    final clean = dateStr.replaceAll("'", '');

    // DD/MM/YYYY
    final dmy = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})');
    final dmyMatch = dmy.firstMatch(clean);
    if (dmyMatch != null) {
      final day = int.parse(dmyMatch.group(1)!);
      final month = int.parse(dmyMatch.group(2)!);
      final year = int.parse(dmyMatch.group(3)!);
      if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
        return DateTime(year, month, day);
      }
    }

    // YYYY-MM-DD
    final ymd = RegExp(r'(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})');
    final ymdMatch = ymd.firstMatch(clean);
    if (ymdMatch != null) {
      final year = int.parse(ymdMatch.group(1)!);
      final month = int.parse(ymdMatch.group(2)!);
      final day = int.parse(ymdMatch.group(3)!);
      if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
        return DateTime(year, month, day);
      }
    }

    return null;
  }

  /// Parse amount string
  double _parseAmount(String amountStr) {
    String cleaned = amountStr.replaceAll(RegExp(r'[^\d,.\-]'), '');
    if (cleaned.isEmpty) return 0;

    if (cleaned.contains('.') && cleaned.contains(',')) {
      final dotIndex = cleaned.lastIndexOf('.');
      final commaIndex = cleaned.lastIndexOf(',');
      if (commaIndex > dotIndex) {
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains(',')) {
      final commaIndex = cleaned.lastIndexOf(',');
      final afterComma = cleaned.substring(commaIndex + 1);
      if (afterComma.length <= 2) {
        cleaned = cleaned.replaceAll(',', '.');
      } else {
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains('.')) {
      final parts = cleaned.split('.');
      if (parts.length > 2) {
        cleaned = cleaned.replaceAll('.', '');
      }
    }

    return double.tryParse(cleaned) ?? 0;
  }

  String _generateHash(DateTime date, double amount, String description) {
    final input = '${date.toIso8601String()}|$amount|$description';
    return md5.convert(utf8.encode(input)).toString();
  }
}
