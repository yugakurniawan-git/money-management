import '../models/transaction.dart';
import '../models/category.dart';

class CategorizerService {
  /// Auto-categorize a transaction based on:
  /// 1. BCA-specific pattern rules (highest priority)
  /// 2. Keyword matching against user's categories
  /// 3. Fallback to "Lainnya"
  String? categorize(String description, List<CategoryModel> categories) {
    final upperDesc = description.toUpperCase();

    // --- LAYER 1: BCA-specific pattern detection ---
    // Returns a category NAME, then we look up its ID
    final bcaCategoryName = _detectBcaPattern(upperDesc);
    if (bcaCategoryName != null) {
      final match = _findCategoryByName(bcaCategoryName, categories);
      if (match != null) return match.id;
    }

    // --- LAYER 2: Keyword matching (from Firestore categories) ---
    for (final category in categories) {
      if (category.keywords.isEmpty) continue; // Skip "Lainnya"
      for (final keyword in category.keywords) {
        if (keyword.isEmpty) continue;
        if (upperDesc.contains(keyword.toUpperCase())) {
          return category.id;
        }
      }
    }

    // --- LAYER 3: No match → return null (caller assigns "Lainnya") ---
    return null;
  }

  /// Categorize a list of transactions
  List<TransactionModel> categorizeAll(
    List<TransactionModel> transactions,
    List<CategoryModel> categories,
  ) {
    return transactions.map((txn) {
      if (txn.categoryId.isNotEmpty) return txn;

      // Try both description and rawDescription
      var categoryId = categorize(txn.description, categories);
      categoryId ??= categorize(txn.rawDescription, categories);

      if (categoryId != null) {
        return txn.copyWith(categoryId: categoryId);
      }
      return txn;
    }).toList();
  }

  // ============================================================
  // BCA PATTERN DETECTION
  // Maps BCA transaction description patterns → category names
  // ============================================================

  String? _detectBcaPattern(String desc) {
    // ---- BIAYA BANK (must check before transfer) ----
    if (desc.contains('BIAYA ADM') || desc.contains('BIAYA ADMIN')) {
      return 'Biaya Bank & Admin';
    }
    if (desc.contains('BIAYA TXN') || desc.contains('BIAYA TRANSAKSI')) {
      return 'Biaya Bank & Admin';
    }
    if (desc.contains('SWITCHING DB BIAYA') ||
        desc.contains('BI-FAST DB BIAYA')) {
      return 'Biaya Bank & Admin';
    }
    if (desc.contains('PAJAK BUNGA')) {
      return 'Biaya Bank & Admin';
    }

    // ---- GAJI / PAYROLL ----
    if (desc.contains('KR OTOMATIS') &&
        (desc.contains('PAYROL') ||
            desc.contains('GAJI') ||
            desc.contains('SALARY'))) {
      return 'Gaji & Payroll';
    }
    // KR OTOMATIS from company (even without PAYROL keyword)
    if (desc.contains('KR OTOMATIS') && desc.contains('PT ')) {
      return 'Gaji & Payroll';
    }
    if (desc.contains('KR OTOMATIS') && desc.contains('LLG')) {
      return 'Gaji & Payroll';
    }

    // ---- TARIK TUNAI ----
    if (desc.contains('TARIKAN ATM') || desc.contains('TARIK TUNAI')) {
      return 'Tarik Tunai';
    }

    // ---- TOP-UP E-WALLET (check before generic transfer) ----
    if (desc.contains('GOPAY') || desc.contains('GOPAY TOPUP')) {
      return 'Top-up E-Wallet';
    }
    if (desc.contains('OVO') && !desc.contains('NOVO')) {
      return 'Top-up E-Wallet';
    }
    if (desc.contains('DANA ') ||
        desc.contains('SHOPEEPAY') ||
        desc.contains('SHOPEE PAY')) {
      return 'Top-up E-Wallet';
    }
    if (desc.contains('LINKAJA') || desc.contains('LINK AJA')) {
      return 'Top-up E-Wallet';
    }
    if (desc.contains('TOPUP') ||
        desc.contains('TOP UP') ||
        desc.contains('TOP-UP')) {
      return 'Top-up E-Wallet';
    }

    // ---- PULSA & INTERNET ----
    if (desc.contains('TELKOMSEL') ||
        desc.contains('MY TELKOMSEL') ||
        desc.contains('TELKOM')) {
      return 'Pulsa & Internet';
    }
    if (desc.contains('INDOSAT') ||
        desc.contains('XL AXIATA') ||
        desc.contains('SMARTFREN')) {
      return 'Pulsa & Internet';
    }
    if (desc.contains('INDIHOME') ||
        desc.contains('BIZNET') ||
        desc.contains('MYREPUBLIC')) {
      return 'Pulsa & Internet';
    }
    if (desc.contains('PULSA') || desc.contains('PAKET DATA')) {
      return 'Pulsa & Internet';
    }

    // ---- LISTRIK & UTILITAS ----
    if (desc.contains('PLN') || desc.contains('TOKEN LISTRIK')) {
      return 'Listrik & Utilitas';
    }
    if (desc.contains('PDAM') || desc.contains('PAM ')) {
      return 'Listrik & Utilitas';
    }

    // ---- QR PAYMENT MERCHANTS (TRANSAKSI DEBIT ... QR) ----
    if (desc.contains('TRANSAKSI DEBIT') || desc.contains('QR ') || desc.contains('QRC')) {
      return _categorizeQrMerchant(desc);
    }

    // ---- TRANSFER MASUK ----
    if (desc.contains('TRSF E-BANKING CR') ||
        desc.contains('TRSF E BANKING CR') ||
        desc.contains('BI-FAST CR')) {
      return 'Transfer Masuk';
    }

    // ---- TRANSFER KELUAR ----
    if (desc.contains('TRSF E-BANKING DB') ||
        desc.contains('TRSF E BANKING DB') ||
        desc.contains('BI-FAST DB TRANSFER') ||
        desc.contains('BI-FAST DB') ||
        desc.contains('SWITCHING DB TRF') ||
        desc.contains('SWITCHING DB')) {
      return 'Transfer Keluar';
    }

    // ---- BUNGA & CASHBACK ----
    if (desc.contains('BUNGA') || desc.contains('INTEREST')) {
      return 'Bunga & Cashback';
    }
    if (desc.contains('CASHBACK') || desc.contains('CASH BACK')) {
      return 'Bunga & Cashback';
    }
    if (desc.contains('REVERSAL') || desc.contains('REFUND')) {
      return 'Bunga & Cashback';
    }

    return null;
  }

  /// Categorize QR payment merchants based on merchant name
  String? _categorizeQrMerchant(String desc) {
    // ---- Makan & Minum ----
    if (_containsAny(desc, [
      'WARUNG', 'KANTIN', 'MAKAN', 'NASI', 'BAKSO', 'MIE ',
      'SOTO', 'SATE', 'AYAM', 'BEBEK', 'IKAN', 'SEAFOOD',
      'RESTO', 'RESTAURANT', 'CAFE', 'COFFEE', 'KOPI',
      'STARBUCKS', 'JANJI JIWA', 'KOPI KENANGAN', 'FORE ',
      'MIXUE', 'HAUS', 'TEGUK', 'TOMORO', 'ZEEN',
      'BOBA', 'BUBBLE', 'TEA ', 'JUICE', 'JAMU',
      'MARTABAK', 'GEPREK', 'DIMSUM', 'RAMEN', 'SUSHI',
      'PIZZA', 'BURGER', 'KEBAB', 'SHAWARMA',
      'KFC', 'MCDONALD', 'MCD ', 'HOKBEN', 'YOSHINOYA',
      'SOLARIA', 'PADANG', 'PECEL', 'RAWON',
      'KEDAI', 'DEPOT', 'RUMAH MAKAN', 'RM ',
      'DAPUR', 'KITCHEN', 'BAKERY', 'ROTI', 'KUE',
      'ES ', 'ICE ',
    ])) {
      return 'Makan & Minum';
    }

    // ---- Minimarket & Grocery ----
    if (_containsAny(desc, [
      'INDOMARET', 'INDOMA', 'IDM ',
      'ALFAMART', 'ALFAMIDI', 'ALFA ',
      'CIRCLE K', 'LAWSON', 'FAMILYMART',
      'SUPERINDO', 'GIANT', 'HYPERMART',
      'TRANSMART', 'LOTTEMART', 'RANCH MARKET',
      'SUPER MARKET', 'SWALAYAN', 'TOKO',
    ])) {
      return 'Minimarket & Grocery';
    }

    // ---- Laundry ----
    if (_containsAny(desc, [
      'LAUND', 'LAUNDRY', 'CUCI', 'CLEAN',
    ])) {
      return 'Laundry';
    }

    // ---- Olahraga & Fitness ----
    if (_containsAny(desc, [
      'BADMINTON', 'BAD ', 'TARUNA BAD', 'GOR ',
      'LAPANGAN', 'FUTSAL', 'SPORT', 'FITNESS', 'GYM',
      'RENANG', 'SWIMMING', 'BASKET', 'TENNIS',
      'YOGA', 'PILATES',
    ])) {
      return 'Olahraga & Fitness';
    }

    // ---- Hiburan & Lifestyle ----
    if (_containsAny(desc, [
      'PREMIERE', 'CINEMA', 'BIOSKOP', 'CGV', 'XXI',
      'KARAOKE', 'BOWLING', 'BILLIARD',
      'NETFLIX', 'SPOTIFY', 'GAME',
      'DUFAN', 'ANCOL', 'WATERBOOM',
    ])) {
      return 'Hiburan & Lifestyle';
    }

    // ---- Belanja & Fashion ----
    if (_containsAny(desc, [
      'HNM', 'H&M', 'ZARA', 'UNIQLO', 'MINISO',
      'COTTON ON', 'PULL&BEAR', 'BERSHKA',
      'MATAHARI', 'RAMAYANA',
      'ACE HARDWARE', 'MR DIY',
      'ELECTRONIC', 'ERAFONE', 'IBOX',
    ])) {
      return 'Belanja & Fashion';
    }

    // ---- Transport ----
    if (_containsAny(desc, [
      'PARKIR', 'PARKING', 'BENSIN', 'PERTAMINA', 'SHELL',
      'GRAB ', 'GOJEK', 'MAXIM', 'TAXI',
      'TOL ', 'ETOLL', 'E-TOLL',
    ])) {
      return 'Transport & Kendaraan';
    }

    // ---- Kesehatan ----
    if (_containsAny(desc, [
      'APOTEK', 'KIMIA FARMA', 'CENTURY',
      'KLINIK', 'DOKTER', 'RS ',
      'OPTIK', 'DENTAL',
    ])) {
      return 'Kesehatan & Obat';
    }

    // ---- Pendidikan ----
    if (_containsAny(desc, [
      'SEKOLAH', 'KAMPUS', 'UNIVERSITAS',
      'KURSUS', 'BIMBEL', 'BUKU',
    ])) {
      return 'Pendidikan';
    }

    // QR payment but unknown merchant → leave uncategorized
    return null;
  }

  /// Helper: check if text contains any of the keywords
  bool _containsAny(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  /// Find category by name (case-insensitive)
  CategoryModel? _findCategoryByName(
      String name, List<CategoryModel> categories) {
    final lower = name.toLowerCase();
    for (final cat in categories) {
      if (cat.name.toLowerCase() == lower) return cat;
    }
    // Partial match fallback
    for (final cat in categories) {
      if (cat.name.toLowerCase().contains(lower) ||
          lower.contains(cat.name.toLowerCase())) {
        return cat;
      }
    }
    return null;
  }
}
