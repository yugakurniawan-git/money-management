import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/stock.dart';

class StockService {
  // ===== Finnhub Configuration =====
  // Daftar gratis di https://finnhub.io → dapatkan API key (gratis, no payment)
  // Taruh API key di sini:
  static const String _finnhubApiKey =
      'd74khb1r01qg1eo5r3kgd74khb1r01qg1eo5r3l0'; // ISI API KEY DI SINI

  static const String _finnhubBase = 'https://finnhub.io/api/v1';

  // ===== Cache =====
  final Map<String, StockModel> _cache = {};
  DateTime? _lastFetch;
  static const _cacheDuration = Duration(minutes: 15);

  bool get _cacheValid =>
      _lastFetch != null &&
      DateTime.now().difference(_lastFetch!) < _cacheDuration;

  bool get hasApiKey => _finnhubApiKey.isNotEmpty;

  // ===== Finnhub Headers =====
  Map<String, String> get _headers => {'Accept': 'application/json'};

  // ===== PUBLIC METHODS =====

  /// Fetch all stock prices via Finnhub /quote endpoint (calls API for each ticker)
  Future<Map<String, StockModel>> fetchAllPrices() async {
    if (_cacheValid && _cache.isNotEmpty) return Map.from(_cache);

    if (!hasApiKey) {
      debugPrint('Finnhub: No API key configured');
      return {};
    }

    try {
      // Fetch quotes for popular tickers
      final tickers = StockModel.popularTickers;
      int loaded = 0;

      for (final ticker in tickers) {
        try {
          // Finnhub quote endpoint: /quote?symbol=TICKER&token=TOKEN
          final symbol = '$ticker.JK'; // IDX stocks need .JK suffix
          final url = Uri.parse(
            '$_finnhubBase/quote?symbol=$symbol&token=$_finnhubApiKey',
          );

          final response = await http
              .get(url, headers: _headers)
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final json = jsonDecode(response.body);

            // Finnhub response: { c: price, d: change, dp: changePercent, ... }
            final price = _toDouble(json['c']);
            final change = _toDouble(json['d']);
            final changePct = _toDouble(json['dp']);

            if (price > 0) {
              final stock = StockModel(
                ticker: ticker,
                name: StockModel.getStockName(ticker),
                price: price,
                change: change,
                changePercent: changePct,
              );
              _cache[ticker] = stock;
              loaded++;
            }
          }

          // Respect rate limit (5 requests/minute on free tier)
          // Simple approach: small delay between requests
          await Future.delayed(const Duration(milliseconds: 250));
        } catch (e) {
          debugPrint('Finnhub quote error for $ticker: $e');
          continue;
        }
      }

      _lastFetch = DateTime.now();
      debugPrint('Finnhub: Loaded $loaded stock prices');
    } catch (e) {
      debugPrint('Finnhub prices error: $e');
    }

    return Map.from(_cache);
  }

  /// Fetch a single stock price
  Future<StockModel?> getStock(String ticker) async {
    final clean = ticker.toUpperCase();
    if (_cacheValid && _cache.containsKey(clean)) {
      return _cache[clean];
    }

    // If cache is empty, fetch all prices (single API call)
    if (_cache.isEmpty || !_cacheValid) {
      await fetchAllPrices();
    }

    return _cache[clean] ?? StockModel.empty(clean);
  }

  /// Fetch multiple stocks (uses cached all-prices data)
  Future<Map<String, StockModel>> getStocks(List<String> tickers) async {
    if (!_cacheValid || _cache.isEmpty) {
      await fetchAllPrices();
    }

    final results = <String, StockModel>{};
    for (final t in tickers) {
      final clean = t.toUpperCase();
      results[clean] = _cache[clean] ?? StockModel.empty(clean);
    }
    return results;
  }

  /// Fetch IHSG (Jakarta Composite Index) via Finnhub /quote for ^JKSE
  Future<StockModel?> getMarketIndex() async {
    if (_cacheValid && _cache.containsKey('IHSG')) {
      return _cache['IHSG'];
    }

    if (!hasApiKey) return null;

    try {
      // ^JKSE is the Finnhub symbol for Jakarta Composite Index
      final url = Uri.parse(
        '$_finnhubBase/quote?symbol=^JKSE&token=$_finnhubApiKey',
      );
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));

      debugPrint('Finnhub market index: HTTP ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        // Finnhub response: { c: price, d: change, dp: changePercent, ... }
        final price = _toDouble(json['c']);
        final change = _toDouble(json['d']);
        final changePct = _toDouble(json['dp']);

        if (price > 0) {
          final stock = StockModel(
            ticker: 'IHSG',
            name: 'Jakarta Composite Index',
            price: price,
            change: change,
            changePercent: changePct,
          );
          _cache['IHSG'] = stock;
          return stock;
        }
      }
    } catch (e) {
      debugPrint('Finnhub market index error: $e');
    }
    return null;
  }

  /// Get trending stocks (Finnhub doesn't have trending, use top movers instead)
  Future<List<StockModel>> getTrendingStocks() async {
    return getTopMovers();
  }

  /// Get top movers (calculated from cached data or fetch fresh)
  Future<List<StockModel>> getTopMovers() async {
    // Fetch latest prices if cache is invalid
    if (!_cacheValid || _cache.isEmpty) {
      await fetchAllPrices();
    }

    // Sort by absolute change percent and take top 10
    final sorted = _cache.values.toList();
    sorted.sort(
      (a, b) => b.changePercent.abs().compareTo(a.changePercent.abs()),
    );
    return sorted.take(10).toList();
  }

  /// Search stocks from cached data + local list
  List<StockModel> searchLocalStocks(String query) {
    final q = query.toUpperCase();

    // Search in cache first (has real data)
    final fromCache =
        _cache.entries
            .where(
              (e) =>
                  e.key.contains(q) || e.value.name.toUpperCase().contains(q),
            )
            .map((e) => e.value)
            .toList();

    if (fromCache.isNotEmpty) return fromCache;

    // Fallback to static list
    return StockModel.popularTickers
        .where(
          (t) =>
              t.contains(q) ||
              StockModel.getStockName(t).toUpperCase().contains(q),
        )
        .map((t) => _cache[t] ?? StockModel.empty(t))
        .toList();
  }

  // ===== HELPERS =====

  static double _toDouble(dynamic val) {
    if (val == null) return 0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0;
    return 0;
  }
}
