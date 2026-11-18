import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inventory_product.dart';
import '../models/stock_movement.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../services/ethiopian_calendar.dart';

class ProductHistoryDialog extends StatefulWidget {
  final InventoryProduct product;
  final bool isAmharic;

  const ProductHistoryDialog({
    super.key,
    required this.product,
    this.isAmharic = true,
  });

  @override
  State<ProductHistoryDialog> createState() => _ProductHistoryDialogState();
}

class _ProductHistoryDialogState extends State<ProductHistoryDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  List<StockMovement> _movements = [];

  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await ApiService.getProductStockMovements(widget.product.id);
      if (mounted) {
        setState(() {
          _movements = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dialogBg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Dialog(
      backgroundColor: dialogBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 14, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.productName,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${LanguageService.t('stockHistory')} · ${widget.product.cartons} ${LanguageService.t('cartons')} (${widget.product.totalPieces.toInt()} ${LanguageService.t('pcsShort')})',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: borderColor),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 36, color: AppTheme.roseDanger),
                                const SizedBox(height: 10),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppTheme.roseDanger, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  onPressed: _loadHistory,
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: Text(LanguageService.t('retry')),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _movements.isEmpty
                          ? AppEmptyState(
                              icon: Icons.history_rounded,
                              title: LanguageService.t('noStockMovements'),
                              message: widget.isAmharic
                                  ? 'ለዚህ ዕቃ እስካሁን የተመዘገበ እንቅስቃሴ የለም።'
                                  : 'No stock movements recorded for this product yet.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _movements.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final m = _movements[index];
                                final isOut = m.isOut;

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.darkSurfaceAlt : Colors.white,
                                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                    border: Border.all(color: borderColor),
                                    boxShadow: AppTheme.softShadow(isDark),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Row 1: Type Badge + Date
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          AppStatusBadge(
                                            label: isOut
                                                ? LanguageService.t('stockOut')
                                                : LanguageService.t('stockIn'),
                                            color: isOut ? AppTheme.roseDanger : AppTheme.emeraldGreen,
                                            icon: isOut ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                            isDense: true,
                                          ),
                                          Text(
                                            EthiopianCalendar.formatAnyDate(
                                              m.transactionDate,
                                              lang: widget.isAmharic ? 'am' : 'en',
                                            ),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Row 2: Quantity and total pieces & Unit Price
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${isOut ? "-" : "+"}${m.cartons} ctn · ${m.quantity.toInt()} pcs',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: isOut ? AppTheme.roseDanger : (isDark ? AppTheme.emeraldGreen : const Color(0xFF047857)),
                                            ),
                                          ),
                                          Text(
                                            'ETB ${_currencyFormat.format(m.unitPrice)}/pc',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),

                                      // Row 3: Balance transition & user
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Balance: ${m.previousStock.toInt()} → ${m.newStock.toInt()} pcs',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                            ),
                                          ),
                                          if (m.userName != null && m.userName!.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isDark ? AppTheme.darkSurface : AppTheme.lightSurfaceAlt,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                m.userName!,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),

                                      if ((m.destination != null && m.destination!.isNotEmpty) ||
                                          (m.sourceId != null && m.sourceId!.isNotEmpty) ||
                                          (m.note != null && m.note!.isNotEmpty))
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            m.destination != null && m.destination!.isNotEmpty
                                                ? 'To: ${m.destination}'
                                                : m.sourceId != null && m.sourceId!.isNotEmpty
                                                    ? 'From: ${m.sourceId}'
                                                    : 'Note: ${m.note}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                              color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
