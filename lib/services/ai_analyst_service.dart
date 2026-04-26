import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/account.dart';

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  const ChatMessage({required this.role, required this.content});
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class AiAnalystService {
  static const String _apiKey = String.fromEnvironment('OPENAI_API_KEY');

  String buildFinancialContext({
    required List<TransactionModel> transactions,
    required List<AccountModel> accounts,
    required Map<String, String> categoryNames,
  }) {
    final now = DateTime.now();
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

    // Account balances
    final accountLines = accounts.isEmpty
        ? '  (belum ada akun)'
        : accounts.map((a) => '  - ${a.bankName} (${a.accountType}): ${fmt.format(a.balance)}').join('\n');

    // All-time totals
    double totalIncome = 0, totalExpense = 0;
    for (final tx in transactions) {
      if (tx.transactionType == 'transfer') continue;
      if (tx.isIncome) { totalIncome += tx.amount; }
      else { totalExpense += tx.amount; }
    }

    // This month
    final thisMonthTx = transactions.where((tx) =>
        tx.transactionDate.year == now.year &&
        tx.transactionDate.month == now.month &&
        tx.transactionType != 'transfer');

    double monthIncome = 0, monthExpense = 0;
    final catExpenses = <String, double>{};
    for (final tx in thisMonthTx) {
      if (tx.isIncome) {
        monthIncome += tx.amount;
      } else {
        monthExpense += tx.amount;
        final cat = categoryNames[tx.categoryId] ?? 'Lainnya';
        catExpenses[cat] = (catExpenses[cat] ?? 0) + tx.amount;
      }
    }

    final topCats = (catExpenses.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .map((e) => '    - ${e.key}: ${fmt.format(e.value)}')
        .join('\n');

    // Last 3 months summary
    final monthLines = <String>[];
    for (int i = 2; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      double inc = 0, exp = 0;
      for (final tx in transactions) {
        if (tx.transactionType == 'transfer') continue;
        if (tx.transactionDate.year == month.year && tx.transactionDate.month == month.month) {
          if (tx.isIncome) { inc += tx.amount; } else { exp += tx.amount; }
        }
      }
      final label = DateFormat('MMMM yyyy', 'id_ID').format(month);
      monthLines.add('    $label → Masuk: ${fmt.format(inc)}, Keluar: ${fmt.format(exp)}, Selisih: ${fmt.format(inc - exp)}');
    }

    // 20 most recent transactions
    final recent = (transactions.toList()
          ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate)))
        .take(20)
        .map((tx) {
          final sign = tx.isIncome ? '+' : '-';
          final cat = categoryNames[tx.categoryId] ?? 'Lainnya';
          final date = DateFormat('dd/MM/yy').format(tx.transactionDate);
          return '    $date $sign${fmt.format(tx.amount)} | ${tx.description} [$cat]';
        })
        .join('\n');

    return '''
DATA KEUANGAN (per ${DateFormat('dd MMMM yyyy', 'id_ID').format(now)}):

AKUN:
$accountLines

TOTAL KESELURUHAN:
  - Pemasukan: ${fmt.format(totalIncome)}
  - Pengeluaran: ${fmt.format(totalExpense)}
  - Saldo bersih: ${fmt.format(totalIncome - totalExpense)}

BULAN INI (${DateFormat('MMMM yyyy', 'id_ID').format(now)}):
  - Pemasukan: ${fmt.format(monthIncome)}
  - Pengeluaran: ${fmt.format(monthExpense)}
  - Selisih: ${fmt.format(monthIncome - monthExpense)}
  Top kategori pengeluaran:
${topCats.isEmpty ? '    (belum ada)' : topCats}

3 BULAN TERAKHIR:
${monthLines.join('\n')}

20 TRANSAKSI TERBARU:
$recent
''';
  }

  Future<String> chat({
    required String userMessage,
    required List<ChatMessage> history,
    required String financialContext,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('OPENAI_API_KEY tidak dikonfigurasi.');
    }

    final messages = [
      {
        'role': 'system',
        'content': '''Kamu adalah asisten keuangan pribadi yang cerdas dan suportif.
Bantu pengguna memahami kondisi keuangannya berdasarkan data transaksi yang diberikan.
Jawab dalam Bahasa Indonesia yang natural, jelas, dan actionable.
Jika kondisi keuangan kurang baik, berikan analisis jujur disertai saran konkret.
Saat menjawab, sebut angka spesifik dari data yang ada agar analisis terasa personal.

$financialContext''',
      },
      ...history.map((m) => m.toJson()),
      {'role': 'user', 'content': userMessage},
    ];

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
        'messages': messages,
        'max_tokens': 1500,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }
  }
}
