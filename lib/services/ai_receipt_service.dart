import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/transaction_item.dart';

class AIReceiptService {
  String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  Future<List<TransactionItem>> scanReceiptItems(String base64Image) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final prompt = """
Anda adalah asisten keuangan yang cerdas. Analisis gambar struk belanja ini dan ekstrak rincian barangnya.
Kembalikan respon hanya dalam bentuk JSON Array berisi objek dengan format ini:
[
  {
    "name": "Nama Barang",
    "amount": Harga barang (integer/double murni tanpa titik terpisah ribuan, tanpa koma, tanpa simbol Rp),
    "categoryId": "Prediksi kategori untuk barang ini (misal: 'Groceries', 'Food', atau 'Lainnya')"
  }
]
PENTING: Jangan tambahkan karakter markdown atau awalan apapun seperti ```json. Berikan output pure JSON Array secara langsung.
""";

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        "model":
            "gpt-4o", // Menggunakan GPT-4o untuk membaca gambar dengan akurat
        "messages": [
          {
            "role": "user",
            "content": [
              {"type": "text", "text": prompt},
              {
                "type": "image_url",
                "image_url": {
                  "url": "data:image/jpeg;base64,$base64Image",
                  "detail": "high",
                },
              },
            ],
          },
        ],
        "max_tokens": 1000,
        "temperature": 0.0, // Suhu 0 agar outputnya selalu konsisten bentuknya
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String content = data['choices'][0]['message']['content'];

      // Membersihkan json jika terbungkus blok markdown dari OpenAI
      content =
          content
              .replaceAll(RegExp(r'```json\n?'), '')
              .replaceAll(RegExp(r'```\n?'), '')
              .trim();

      List<dynamic> jsonList = jsonDecode(content);

      return jsonList.map((item) {
        return TransactionItem(
          name: item['name'].toString(),
          amount: double.tryParse(item['amount'].toString()) ?? 0,
          categoryId: item['categoryId'].toString(),
        );
      }).toList();
    } else {
      print('Error from OpenAI: ${response.body}');
      throw Exception(
        'Gagal memproses struk menggunakan AI: Kode error ${response.statusCode}',
      );
    }
  }
}
