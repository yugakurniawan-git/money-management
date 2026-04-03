import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/stock.dart';
import '../../theme/app_colors.dart';
import '../common/glass_container.dart';

class StockCard extends StatelessWidget {
  final StockModel stock;
  final VoidCallback? onTap;
  final bool compact;

  const StockCard({
    super.key,
    required this.stock,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'id_ID');
    final hasPrice = stock.price > 0;
    final changeColor = stock.isUp ? AppColors.income : AppColors.expense;

    if (compact) {
      return _buildCompact(fmt, hasPrice, changeColor);
    }

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Ticker badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: stock.isUp
                    ? AppColors.incomeGradient
                    : AppColors.expenseGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  stock.ticker.length > 4
                      ? stock.ticker.substring(0, 4)
                      : stock.ticker,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.ticker,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    stock.name,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Price & change
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  hasPrice ? 'Rp ${fmt.format(stock.price)}' : '-',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (hasPrice)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: changeColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${stock.isUp ? '+' : ''}${stock.changePercent.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: changeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Text(
                    'N/A',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(NumberFormat fmt, bool hasPrice, Color changeColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (stock.isUp ? AppColors.income : AppColors.expense).withAlpha(20),
              (stock.isUp ? AppColors.income : AppColors.expense).withAlpha(8),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                (stock.isUp ? AppColors.income : AppColors.expense).withAlpha(40),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  stock.ticker,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const Spacer(),
                Icon(
                  stock.isUp ? Icons.trending_up : Icons.trending_down,
                  color: changeColor,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hasPrice ? 'Rp ${fmt.format(stock.price)}' : '-',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              hasPrice
                  ? '${stock.isUp ? '+' : ''}${stock.changePercent.toStringAsFixed(2)}%'
                  : 'N/A',
              style: TextStyle(
                color: changeColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
