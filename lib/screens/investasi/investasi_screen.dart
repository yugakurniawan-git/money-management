import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/stock.dart';
import '../../theme/app_colors.dart';
import '../../providers/cold_money_provider.dart';
import '../../providers/stock_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/stock/cold_money_card.dart';
import '../../widgets/stock/stock_card.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/staggered_list_animation.dart';
import '../../widgets/common/animated_number.dart';
import 'stock_detail_screen.dart';

class InvestasiScreen extends ConsumerWidget {
  const InvestasiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coldMoney = ref.watch(coldMoneyProvider);
    final hasKey = ref.watch(hasApiKeyProvider);
    final watchlist = ref.watch(watchlistProvider);
    final watchlistPrices = ref.watch(watchlistPricesProvider);
    final marketIndex = ref.watch(marketIndexProvider);
    final topMovers = ref.watch(topMoversProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Investasi')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(marketIndexProvider);
          ref.invalidate(topMoversProvider);
          ref.invalidate(watchlistPricesProvider);
          ref.invalidate(popularStocksProvider);
          ref.invalidate(allStockPricesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Uang Dingin card
            StaggeredListItem(index: 0, child: ColdMoneyCard(data: coldMoney)),
            const SizedBox(height: 20),

            // API Key warning
            if (!hasKey)
              StaggeredListItem(
                index: 1,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.key, color: AppColors.warning, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Masukkan API Key GoAPI.io di stock_service.dart untuk data saham real-time.\nDaftar gratis di goapi.io',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!hasKey) const SizedBox(height: 16),

            // 2. IHSG Market Index
            StaggeredListItem(
              index: hasKey ? 1 : 2,
              child: _MarketIndexCard(marketIndex: marketIndex),
            ),
            const SizedBox(height: 20),

            // 3. Watchlist
            StaggeredListItem(
              index: 2,
              child: _SectionHeader(
                title: 'Watchlist Kamu',
                icon: Icons.star_outline,
                trailing: GestureDetector(
                  onTap: () => _showAddWatchlistSheet(context, ref),
                  child: ShaderMask(
                    shaderCallback: (bounds) =>
                        AppColors.primaryGradient.createShader(bounds),
                    child: const Text(
                      '+ Tambah',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            watchlist.when(
              loading: () => const Center(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator())),
              error: (e, _) => Text('Error: $e'),
              data: (items) {
                if (items.isEmpty) {
                  return GlassContainer(
                    child: Column(
                      children: [
                        Icon(Icons.star_border,
                            color: AppColors.textSecondary, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Belum ada saham di watchlist.\nTambahkan saham untuk memantau harga.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }
                final prices = watchlistPrices.value ?? {};
                return Column(
                  children: items.asMap().entries.map((e) {
                    final item = e.value;
                    final stock =
                        prices[item.ticker] ?? StockModel.empty(item.ticker);
                    return Dismissible(
                      key: Key(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          gradient: AppColors.expenseGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.white),
                      ),
                      onDismissed: (_) {
                        ref
                            .read(firebaseServiceProvider)
                            .removeFromWatchlist(item.id);
                      },
                      child: StaggeredListItem(
                        index: 3 + e.key,
                        child: StockCard(
                          stock: stock,
                          onTap: () => _openStockDetail(context, stock),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),

            // 4. Top Movers
            StaggeredListItem(
              index: 6,
              child: _SectionHeader(
                title: 'Top Movers Hari Ini',
                icon: Icons.local_fire_department_outlined,
              ),
            ),
            const SizedBox(height: 8),
            topMovers.when(
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => GlassContainer(
                child: Text(
                  'Data saham tidak tersedia.\nCoba refresh nanti.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
              data: (movers) {
                if (movers.isEmpty) {
                  return GlassContainer(
                    child: Text(
                      'Data tidak tersedia. Pull down untuk refresh.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  );
                }
                return SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: movers.length,
                    itemBuilder: (context, i) => StockCard(
                      stock: movers[i],
                      compact: true,
                      onTap: () => _openStockDetail(context, movers[i]),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // 5. Popular Stocks
            StaggeredListItem(
              index: 7,
              child: _SectionHeader(
                title: 'Saham Populer IDX',
                icon: Icons.trending_up,
              ),
            ),
            const SizedBox(height: 8),
            _PopularStocksList(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _openStockDetail(BuildContext context, StockModel stock) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => StockDetailScreen(stock: stock),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  void _showAddWatchlistSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddWatchlistSheet(),
    );
  }
}

// ---- Section Header ----

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  const _SectionHeader({required this.title, required this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ---- Market Index Card ----

class _MarketIndexCard extends StatelessWidget {
  final AsyncValue<StockModel?> marketIndex;
  const _MarketIndexCard({required this.marketIndex});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: marketIndex.when(
        loading: () => Row(
          children: [
            const Icon(Icons.bar_chart, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            const Text('IHSG', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            ),
          ],
        ),
        error: (_, __) => Row(
          children: [
            const Icon(Icons.bar_chart, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            const Text('IHSG', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('Tidak tersedia',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
        data: (index) {
          if (index == null || index.price == 0) {
            return Row(
              children: [
                const Icon(Icons.bar_chart, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                const Text('IHSG',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('Tidak tersedia',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            );
          }
          final changeColor =
              index.isUp ? AppColors.income : AppColors.expense;
          return Row(
            children: [
              const Icon(Icons.bar_chart, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('IHSG',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('Jakarta Composite',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedNumber(
                    value: index.price,
                    decimalPlaces: 2,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: changeColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          index.isUp
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          color: changeColor,
                          size: 16,
                        ),
                        Text(
                          '${index.isUp ? '+' : ''}${index.changePercent.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: changeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---- Popular Stocks List ----

class _PopularStocksList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popular = ref.watch(popularStocksProvider);
    return popular.when(
      loading: () => const Center(
          child: Padding(
              padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
      error: (_, __) => GlassContainer(
        child: Text(
          'Gagal memuat data saham populer.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
      data: (stocks) {
        if (stocks.isEmpty) {
          return GlassContainer(
            child: Text('Data tidak tersedia.',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        final list = stocks.values.toList()
          ..sort((a, b) => b.changePercent.abs().compareTo(a.changePercent.abs()));
        return Column(
          children: list.asMap().entries.map((e) {
            return StaggeredListItem(
              index: 8 + e.key,
              child: StockCard(
                stock: e.value,
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) =>
                          StockDetailScreen(stock: e.value),
                      transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(opacity: anim, child: child),
                      transitionDuration: const Duration(milliseconds: 250),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ---- Add Watchlist Bottom Sheet ----

class _AddWatchlistSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddWatchlistSheet> createState() => _AddWatchlistSheetState();
}

class _AddWatchlistSheetState extends ConsumerState<_AddWatchlistSheet> {
  final _searchController = TextEditingController();
  List<StockModel> _results = [];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withAlpha(60),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cari saham (BBCA, TLKM...)',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (q) {
                setState(() {
                  _results = ref
                      .read(stockServiceProvider)
                      .searchLocalStocks(q);
                });
              },
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.isEmpty
                          ? 'Ketik ticker atau nama saham'
                          : 'Tidak ditemukan',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final stock = _results[i];
                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              stock.ticker.length > 4
                                  ? stock.ticker.substring(0, 4)
                                  : stock.ticker,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        title: Text(stock.ticker,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(stock.name,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline,
                              color: AppColors.primary),
                          onPressed: () async {
                            final item = WatchlistItemModel(
                              id: const Uuid().v4(),
                              ticker: stock.ticker,
                              name: stock.name,
                            );
                            await ref
                                .read(firebaseServiceProvider)
                                .addToWatchlist(item);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '${stock.ticker} ditambahkan ke watchlist'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                              Navigator.pop(context);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
