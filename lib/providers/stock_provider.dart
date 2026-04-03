import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stock.dart';
import '../services/stock_service.dart';
import 'transaction_provider.dart';

final stockServiceProvider = Provider<StockService>((ref) => StockService());

/// Whether GoAPI key is configured
final hasApiKeyProvider = Provider<bool>((ref) {
  return ref.watch(stockServiceProvider).hasApiKey;
});

/// Watchlist from Firestore (auth-guarded)
final watchlistProvider = StreamProvider<List<WatchlistItemModel>>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(firebaseServiceProvider).getWatchlist();
});

/// IHSG market index
final marketIndexProvider = FutureProvider<StockModel?>((ref) {
  return ref.watch(stockServiceProvider).getMarketIndex();
});

/// Top movers (gainer + loser from GoAPI)
final topMoversProvider = FutureProvider<List<StockModel>>((ref) {
  return ref.watch(stockServiceProvider).getTopMovers();
});

/// All stock prices (single GoAPI call)
final allStockPricesProvider =
    FutureProvider<Map<String, StockModel>>((ref) async {
  return ref.watch(stockServiceProvider).fetchAllPrices();
});

/// Stock prices for watchlist tickers
final watchlistPricesProvider =
    FutureProvider<Map<String, StockModel>>((ref) async {
  final watchlist = ref.watch(watchlistProvider).value ?? [];
  if (watchlist.isEmpty) return {};
  final tickers = watchlist.map((w) => w.ticker).toList();
  return ref.watch(stockServiceProvider).getStocks(tickers);
});

/// Popular stocks with prices (from cached all-prices data)
final popularStocksProvider =
    FutureProvider<Map<String, StockModel>>((ref) async {
  final tickers = StockModel.popularTickers.take(20).toList();
  return ref.watch(stockServiceProvider).getStocks(tickers);
});

/// Search stocks locally
final stockSearchQueryProvider = StateProvider<String>((ref) => '');

final stockSearchResultsProvider = Provider<List<StockModel>>((ref) {
  final query = ref.watch(stockSearchQueryProvider);
  if (query.isEmpty) return [];
  return ref.watch(stockServiceProvider).searchLocalStocks(query);
});
