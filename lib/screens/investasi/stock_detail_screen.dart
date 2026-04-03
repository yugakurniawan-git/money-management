import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/stock.dart';
import '../../theme/app_colors.dart';
import '../../providers/stock_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/animated_number.dart';
import '../../widgets/common/gradient_button.dart';

class StockDetailScreen extends ConsumerWidget {
  final StockModel stock;
  const StockDetailScreen({super.key, required this.stock});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat('#,##0', 'id_ID');
    final hasPrice = stock.price > 0;
    final changeColor = stock.isUp ? AppColors.income : AppColors.expense;
    final watchlist = ref.watch(watchlistProvider).value ?? [];
    final isInWatchlist =
        watchlist.any((w) => w.ticker == stock.ticker);

    return Scaffold(
      appBar: AppBar(
        title: Text(stock.ticker),
        actions: [
          IconButton(
            icon: Icon(
              isInWatchlist ? Icons.star : Icons.star_border,
              color: isInWatchlist ? AppColors.warning : null,
            ),
            onPressed: () async {
              if (isInWatchlist) {
                final item =
                    watchlist.firstWhere((w) => w.ticker == stock.ticker);
                await ref
                    .read(firebaseServiceProvider)
                    .removeFromWatchlist(item.id);
              } else {
                await ref
                    .read(firebaseServiceProvider)
                    .addToWatchlist(WatchlistItemModel(
                      id: const Uuid().v4(),
                      ticker: stock.ticker,
                      name: stock.name,
                    ));
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Price card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: stock.isUp
                  ? AppColors.incomeGradient
                  : AppColors.expenseGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: changeColor.withAlpha(50),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  stock.name,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Rp ',
                        style: TextStyle(color: Colors.white70, fontSize: 18)),
                    AnimatedNumber(
                      value: stock.price,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (hasPrice) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          stock.isUp
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          color: Colors.white,
                          size: 20,
                        ),
                        Text(
                          '${stock.isUp ? '+' : ''}${fmt.format(stock.change)} (${stock.changePercent.toStringAsFixed(2)}%)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Info cards
          if (hasPrice) ...[
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _InfoRow('Ticker', stock.ticker),
                  _InfoRow('Nama', stock.name),
                  _InfoRow('Harga', 'Rp ${fmt.format(stock.price)}'),
                  _InfoRow(
                      'Perubahan',
                      '${stock.isUp ? '+' : ''}Rp ${fmt.format(stock.change)}'),
                  _InfoRow('Perubahan %',
                      '${stock.changePercent.toStringAsFixed(2)}%'),
                  if (stock.volume > 0)
                    _InfoRow('Volume', fmt.format(stock.volume)),
                ],
              ),
            ),
          ] else
            GlassContainer(
              child: Column(
                children: [
                  Icon(Icons.cloud_off,
                      color: AppColors.textSecondary, size: 40),
                  const SizedBox(height: 10),
                  Text(
                    'Data harga tidak tersedia saat ini.\nCoba lagi nanti.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Add/Remove watchlist button
          GradientButton(
            text: isInWatchlist
                ? 'Hapus dari Watchlist'
                : 'Tambah ke Watchlist',
            gradient: isInWatchlist
                ? AppColors.expenseGradient
                : AppColors.primaryGradient,
            icon: isInWatchlist ? Icons.star : Icons.star_border,
            onPressed: () async {
              if (isInWatchlist) {
                final item =
                    watchlist.firstWhere((w) => w.ticker == stock.ticker);
                await ref
                    .read(firebaseServiceProvider)
                    .removeFromWatchlist(item.id);
              } else {
                await ref
                    .read(firebaseServiceProvider)
                    .addToWatchlist(WatchlistItemModel(
                      id: const Uuid().v4(),
                      ticker: stock.ticker,
                      name: stock.name,
                    ));
              }
            },
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
