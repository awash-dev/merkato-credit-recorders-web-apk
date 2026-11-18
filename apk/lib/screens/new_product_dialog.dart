import 'dart:async';

import 'package:flutter/material.dart';
import 'package:et_date_picker/et_date_picker.dart';

import '../models/user.dart';
import '../models/inventory_product.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/ethiopian_calendar.dart';
import '../theme/app_theme.dart';

class NewProductDialog extends StatefulWidget {
  final AppUser currentUser;
  final String? activeStoreId;
  final bool isAmharic;

  const NewProductDialog({
    super.key,
    required this.currentUser,
    this.activeStoreId,
    this.isAmharic = true,
  });

  @override
  State<NewProductDialog> createState() => _NewProductDialogState();
}

class _NewProductDialogState extends State<NewProductDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _storekeeperPriceController = TextEditingController();
  final _pcsPerCartonController = TextEditingController(text: '1');
  final _openingCartonsController = TextEditingController(text: '0');
  final _minStockController = TextEditingController(text: '0');
  final _dateController = TextEditingController();
  Timer? _autocompleteTimer;
  List<InventoryProduct> _suggestions = [];
  DateTime _selectedDate = DateTime.now();
  final String _calendarMode = 'ethiopian';

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateTime.now().toIso8601String().split('T')[0];

    _pcsPerCartonController.addListener(_onCalculationsChanged);
    _openingCartonsController.addListener(_onCalculationsChanged);
    _unitPriceController.addListener(_onCalculationsChanged);
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _pcsPerCartonController.removeListener(_onCalculationsChanged);
    _openingCartonsController.removeListener(_onCalculationsChanged);
    _unitPriceController.removeListener(_onCalculationsChanged);
    _nameController.removeListener(_onNameChanged);
    _autocompleteTimer?.cancel();
    _nameController.dispose();
    _unitPriceController.dispose();
    _storekeeperPriceController.dispose();
    _pcsPerCartonController.dispose();
    _openingCartonsController.dispose();
    _minStockController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _onCalculationsChanged() {
    setState(() {});
  }

  void _onNameChanged() {
    _autocompleteTimer?.cancel();
    final query = _nameController.text.trim();
    if (query.length < 2) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }
    _autocompleteTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final storeId = (widget.activeStoreId != null &&
                widget.activeStoreId!.isNotEmpty &&
                widget.activeStoreId != 'all')
            ? widget.activeStoreId
            : (widget.currentUser.storeId ??
                (widget.activeStoreId == 'all' ? null : widget.activeStoreId));
        final products = await ApiService.getInventoryProducts(
          storeId: storeId,
        );
        if (!mounted) return;
        final matches = products
            .where(
              (p) => p.productName.toLowerCase().contains(query.toLowerCase()),
            )
            .take(8)
            .toList();
        setState(() => _suggestions = matches);
      } catch (_) {
        if (mounted) setState(() => _suggestions = []);
      }
    });
  }

  double get _pcsPerCarton {
    final v = double.tryParse(_pcsPerCartonController.text.trim()) ?? 1.0;
    return v > 0 ? v : 1.0;
  }

  double get _openingCartons =>
      double.tryParse(_openingCartonsController.text.trim()) ?? 0.0;

  /// Total Pieces = Opening Cartons × Pieces per Carton
  int get _totalInitialPieces => (_openingCartons * _pcsPerCarton).round();

  double get _unitPrice =>
      double.tryParse(_unitPriceController.text.trim()) ?? 0.0;
  double get _totalValue => _totalInitialPieces * _unitPrice;

  void _selectSuggestion(InventoryProduct product) async {
    final pcs = product.pcsPerCarton > 0
        ? (product.pcsPerCarton % 1 == 0
            ? product.pcsPerCarton.toInt().toString()
            : product.pcsPerCarton.toString())
        : '1';
    final price = product.unitPrice > 0
        ? (product.unitPrice % 1 == 0
            ? product.unitPrice.toInt().toString()
            : product.unitPrice.toString())
        : (product.costPrice > 0
            ? (product.costPrice % 1 == 0
                ? product.costPrice.toInt().toString()
                : product.costPrice.toString())
            : '');
    final minStock = product.minimumStock % 1 == 0
        ? product.minimumStock.toInt().toString()
        : product.minimumStock.toString();
    final skPrice = product.storekeeperPrice > 0
        ? (product.storekeeperPrice % 1 == 0
            ? product.storekeeperPrice.toInt().toString()
            : product.storekeeperPrice.toString())
        : price;

    _nameController.text = product.productName;
    _pcsPerCartonController.text = pcs;
    _unitPriceController.text = price;
    _storekeeperPriceController.text = skPrice;
    _minStockController.text = minStock;
    _openingCartonsController.text = '0';
    setState(() => _suggestions = []);

    // Fetch fresh database record to ensure latest saved data
    if (product.id.isNotEmpty) {
      try {
        final fresh = await ApiService.getProductById(product.id);
        if (fresh != null && mounted) {
          final freshPcs = fresh.pcsPerCarton > 0
              ? (fresh.pcsPerCarton % 1 == 0
                  ? fresh.pcsPerCarton.toInt().toString()
                  : fresh.pcsPerCarton.toString())
              : '1';
          final freshPrice = fresh.unitPrice > 0
              ? (fresh.unitPrice % 1 == 0
                  ? fresh.unitPrice.toInt().toString()
                  : fresh.unitPrice.toString())
              : (fresh.costPrice > 0
                  ? (fresh.costPrice % 1 == 0
                      ? fresh.costPrice.toInt().toString()
                      : fresh.costPrice.toString())
                  : '');
          final freshSk = fresh.storekeeperPrice > 0
              ? (fresh.storekeeperPrice % 1 == 0
                  ? fresh.storekeeperPrice.toInt().toString()
                  : fresh.storekeeperPrice.toString())
              : freshPrice;
          final freshMin = fresh.minimumStock % 1 == 0
              ? fresh.minimumStock.toInt().toString()
              : fresh.minimumStock.toString();

          setState(() {
            _nameController.text = fresh.productName;
            _pcsPerCartonController.text = freshPcs;
            _unitPriceController.text = freshPrice;
            _storekeeperPriceController.text = freshSk;
            _minStockController.text = freshMin;
          });
        }
      } catch (_) {}
    }
  }

  String get _displayDate {
    if (_calendarMode == 'gregorian') {
      return _dateController.text;
    }
    final eth = EthiopianCalendar.toEthiopian(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return EthiopianCalendar.formatDisplay(
      eth,
      lang: widget.isAmharic ? 'am' : 'en',
    );
  }

  Future<void> _pickDate() async {
    final result = await showEthiopianDatePickerDialog(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      showSelectedDatePreview: true,
      useEthiopicNumerals: false,
      cancelText: LanguageService.t('cancel'),
      confirmText: LanguageService.t('confirm'),
    );
    if (result != null) {
      final picked = result.gregorianDate;
      setState(() {
        _selectedDate = picked;
        _dateController.text =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    if (_openingCartons < 0 || _unitPrice < 0) {
      setState(
        () => _errorMessage = LanguageService.t('quantitiesPricesNegative'),
      );
      return;
    }
    final targetStoreId = (widget.activeStoreId != null &&
            widget.activeStoreId!.isNotEmpty &&
            widget.activeStoreId != 'all')
        ? widget.activeStoreId
        : (widget.currentUser.storeId ??
            (widget.activeStoreId == 'all' ? null : widget.activeStoreId));

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // If product with same name exists, registerProduct merges and updates seamlessly (Fix duplicate same names)

      final skPrice = double.tryParse(_storekeeperPriceController.text.trim()) ?? _unitPrice;
      final product = await ApiService.registerProduct(
        productName: name,
        unitPrice: _unitPrice,
        storekeeperPrice: skPrice,
        pcsPerCarton: _pcsPerCarton,
        openingCartons: _openingCartons,
        openingLoosePieces: 0,
        minimumStock: double.tryParse(_minStockController.text.trim()) ?? 0.0,
        costPrice: _unitPrice,
        storeId: targetStoreId,
        createdBy: widget.currentUser.id,
        date: _dateController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, product);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final dialogBg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;

    return Dialog(
      backgroundColor: dialogBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.add_box_outlined,
                            size: 22,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            LanguageService.t('newProductRegistration'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                    ),

                  // 1. Product Name (Text input, NOT dropdown)
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: LanguageService.t('productNameStar'),
                      hintText: LanguageService.t('e.gPaper'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return LanguageService.t('productNameRequired');
                      }
                      return null;
                    },
                  ),
                  if (_suggestions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2638) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final product = _suggestions[index];
                          return ListTile(
                            dense: true,
                            title: Text(product.productName),
                            subtitle: Text(
                              '${product.pcsPerCarton} pcs/carton · ${product.unitPrice} ETB',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: const Icon(Icons.north_west, size: 16),
                            onTap: () => _selectSuggestion(product),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // 2. Pieces per Carton & Opening Cartons
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pcsPerCartonController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: widget.isAmharic
                                ? 'ፍሬ በካርቶን'
                                : 'Pieces / Carton',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          validator: (v) {
                            final n = double.tryParse(v?.trim() ?? '');
                            if (n == null || n <= 0) {
                              return LanguageService.t('mustBeGreaterThanZero');
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _openingCartonsController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: LanguageService.t('openingCartons'),
                            hintText: '0',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          validator: (v) {
                            final n = double.tryParse(v?.trim() ?? '');
                            if (n == null || n < 0) {
                              return widget.isAmharic
                                  ? 'አሉታዊ ሊሆን አይችልም'
                                  : 'Cannot be negative';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 3. Automatic Calculation Box (Opening Cartons × Pieces per Carton)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2638)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              LanguageService.t('totalPieces'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              '$_totalInitialPieces ${LanguageService.t('pcsShort')}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                           LanguageService.t('formula').replaceAll('{cartons}', _openingCartons.toInt().toString()).replaceAll('{pcs}', _pcsPerCarton.toInt().toString()).replaceAll('{total}', _totalInitialPieces.toString()),
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          LanguageService.t('totalValue').replaceAll('{value}', _totalValue.toStringAsFixed(2)),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. Unit Price & Minimum Stock
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _unitPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: widget.isAmharic
                                ? 'የአንዱ ዋጋ (ብር)'
                                : 'Unit Price (ETB)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return widget.isAmharic
                                  ? 'ዋጋ ያስፈልጋል'
                                  : 'Price required';
                            }
                            final price = double.tryParse(v.trim());
                            if (price == null) {
                              return widget.isAmharic
                                  ? 'ትክክለኛ ቁጥር ያስገቡ'
                                  : 'Invalid number';
                            }
                            if (price < 0) {
                              return widget.isAmharic
                                  ? 'አሉታዊ ሊሆን አይችልም'
                                  : 'Cannot be negative';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _minStockController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: widget.isAmharic
                                ? 'ዝቅተኛ ክምችት'
                                : 'Minimum Stock',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Storekeeper Price (Single piece price)
                  TextFormField(
                    controller: _storekeeperPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: widget.isAmharic
                          ? 'የመደብር ሠራተኛ ዋጋ (ነጠላ ፍሬ)'
                          : 'Storekeeper Price (Single Piece ETB)',
                      hintText: LanguageService.t('e.g60'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 5. Date
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: LanguageService.t('date'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        _displayDate,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(LanguageService.t('cancel')),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check, size: 16),
                        label: Text(
                            _isSaving
                                ? LanguageService.t('saving')
                                : LanguageService.t('registerProduct'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
