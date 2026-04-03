import 'package:cloud_firestore/cloud_firestore.dart';

class StockModel {
  final String ticker;
  final String name;
  final double price;
  final double change;
  final double changePercent;
  final int volume;
  final DateTime lastUpdated;

  StockModel({
    required this.ticker,
    required this.name,
    required this.price,
    this.change = 0,
    this.changePercent = 0,
    this.volume = 0,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  bool get isUp => change >= 0;

  /// Parse from GoAPI /stock/idx/prices response item
  /// GoAPI fields may include: ticker/symbol, name/company, close/last/price,
  /// change, percent/change_percent, volume
  factory StockModel.fromGoApi(Map<String, dynamic> json) {
    try {
      final ticker = (json['ticker'] ?? json['symbol'] ?? '').toString().toUpperCase();
      if (ticker.isEmpty) return StockModel.empty('');

      final name = (json['name'] ?? json['company'] ?? _tickerNames[ticker] ?? ticker).toString();
      final price = _toDouble(json['close'] ?? json['last'] ?? json['price']);
      final change = _toDouble(json['change']);
      final changePct = _toDouble(json['percent'] ?? json['change_percent']);
      final volume = _toInt(json['volume']);

      return StockModel(
        ticker: ticker,
        name: name,
        price: price,
        change: change,
        changePercent: changePct,
        volume: volume,
      );
    } catch (_) {
      return StockModel.empty(json['ticker']?.toString() ?? '');
    }
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0;
    return 0;
  }

  static int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  factory StockModel.empty(String ticker) {
    final clean = ticker.replaceAll('.JK', '');
    return StockModel(
      ticker: clean,
      name: _tickerNames[clean] ?? clean,
      price: 0,
    );
  }

  /// Popular IDX stock tickers with full names
  static const Map<String, String> _tickerNames = {
    'BBCA': 'Bank Central Asia',
    'BBRI': 'Bank Rakyat Indonesia',
    'BMRI': 'Bank Mandiri',
    'BBNI': 'Bank Negara Indonesia',
    'TLKM': 'Telkom Indonesia',
    'ASII': 'Astra International',
    'UNVR': 'Unilever Indonesia',
    'HMSP': 'HM Sampoerna',
    'GOTO': 'GoTo Gojek Tokopedia',
    'BREN': 'Barito Renewables',
    'AMRT': 'Sumber Alfaria (Alfamart)',
    'ICBP': 'Indofood CBP',
    'INDF': 'Indofood Sukses Makmur',
    'KLBF': 'Kalbe Farma',
    'PGAS': 'Perusahaan Gas Negara',
    'EXCL': 'XL Axiata',
    'MDKA': 'Merdeka Copper Gold',
    'ACES': 'Ace Hardware Indonesia',
    'CPIN': 'Charoen Pokphand',
    'MIKA': 'Mitra Keluarga',
    'ANTM': 'Aneka Tambang',
    'PTBA': 'Bukit Asam',
    'ADRO': 'Adaro Energy',
    'ISAT': 'Indosat Ooredoo',
    'SMGR': 'Semen Indonesia',
    'JPFA': 'Japfa Comfeed',
    'BRIS': 'Bank Syariah Indonesia',
    'ARTO': 'Bank Jago',
    'ESSA': 'Essa Industries',
    'INKP': 'Indah Kiat Pulp',
  };

  static List<String> get popularTickers => _tickerNames.keys.toList();
  static String getStockName(String ticker) => _tickerNames[ticker] ?? ticker;
}

class WatchlistItemModel {
  final String id;
  final String ticker;
  final String name;
  final DateTime addedAt;

  WatchlistItemModel({
    required this.id,
    required this.ticker,
    required this.name,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  factory WatchlistItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WatchlistItemModel(
      id: doc.id,
      ticker: data['ticker'] ?? '',
      name: data['name'] ?? '',
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ticker': ticker,
      'name': name,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }
}
