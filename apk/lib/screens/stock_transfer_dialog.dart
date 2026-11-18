import 'package:flutter/material.dart';
import 'package:et_date_picker/et_date_picker.dart';
import '../models/inventory_product.dart';
import '../models/store.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/ethiopian_calendar.dart';
import '../theme/app_theme.dart';

class StockTransferDialog extends StatefulWidget {
  final AppUser currentUser;
  final List<Store> availableStores;
  final String? initialFromStoreId;
  final List<InventoryProduct> availableProducts;
  final bool isAmharic;

  const StockTransferDialog({
    super.key,
    required this.currentUser,
    required this.availableStores,
    this.initialFromStoreId,
    required this.availableProducts,
    this.isAmharic = true,
  });

  @override
  State<StockTransferDialog> createState() => _StockTransferDialogState();
}

class _StockTransferDialogState extends State<StockTransferDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _fromStoreId;
  String? _toStoreId;
  InventoryProduct? _selectedProduct;
  List<InventoryProduct> _sourceProducts = [];

  final _productSearchController = TextEditingController();
  final _cartonsController = TextEditingController(text: '1');
  final _piecesController = TextEditingController(text: '0');
  final _refNumberController = TextEditingController();
  final _notesController = TextEditingController();
  final _dateController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  bool _isLoadingSource = false;
  bool _isTransferring = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    final eth = EthiopianCalendar.toEthiopian(now.year, now.month, now.day);
    _dateController.text = EthiopianCalendar.formatDisplay(
      eth,
      lang: widget.isAmharic ? 'am' : 'en',
    );
    _refNumberController.text = 'TRF-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';

    // Initialize from and to store
    final validStores = widget.availableStores.where((s) => s.id != 'all').toList();
    if (widget.initialFromStoreId != null &&
        widget.initialFromStoreId != 'all' &&
        validStores.any((s) => s.id == widget.initialFromStoreId)) {
      _fromStoreId = widget.initialFromStoreId;
    } else if (validStores.isNotEmpty) {
      _fromStoreId = validStores.first.id;
    }

    final destList = validStores.where((s) => s.id != _fromStoreId).toList();
    if (destList.isNotEmpty) {
      _toStoreId = destList.first.id;
    }

    _cartonsController.addListener(_onQuantityChanged);
    _piecesController.addListener(_onQuantityChanged);

    if (_fromStoreId != null) {
      _loadSourceProducts(_fromStoreId!);
    }
  }

  @override
  void dispose() {
    _cartonsController.removeListener(_onQuantityChanged);
    _piecesController.removeListener(_onQuantityChanged);
    _productSearchController.dispose();
    _cartonsController.dispose();
    _piecesController.dispose();
    _refNumberController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _onQuantityChanged() {
    setState(() {});
  }

  Future<void> _loadSourceProducts(String storeId) async {
    setState(() {
      _isLoadingSource = true;
      _selectedProduct = null;
      _productSearchController.clear();
    });

    try {
      final list = await ApiService.getInventoryProducts(storeId: storeId);
      if (mounted) {
        setState(() {
          _sourceProducts = list.where((p) => p.currentQuantity > 0).toList();
          _isLoadingSource = false;
          if (_sourceProducts.isNotEmpty) {
            _selectedProduct = _sourceProducts.first;
            _productSearchController.text = _selectedProduct!.productName;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sourceProducts = widget.availableProducts
              .where((p) => (p.storeId == storeId || p.storeId == null) && p.currentQuantity > 0)
              .toList();
          _isLoadingSource = false;
          if (_sourceProducts.isNotEmpty) {
            _selectedProduct = _sourceProducts.first;
            _productSearchController.text = _selectedProduct!.productName;
          }
        });
      }
    }
  }

  double get _enteredCartons => double.tryParse(_cartonsController.text.trim()) ?? 0.0;
  double get _enteredLoosePieces => double.tryParse(_piecesController.text.trim()) ?? 0.0;

  double get _pcsPerCarton {
    if (_selectedProduct == null || _selectedProduct!.pcsPerCarton <= 0) return 1.0;
    return _selectedProduct!.pcsPerCarton;
  }

  double get _totalTransferPieces => (_enteredCartons * _pcsPerCarton) + _enteredLoosePieces;

  double get _availablePieces => _selectedProduct?.currentQuantity ?? 0.0;

  bool get _isInsufficientStock => _totalTransferPieces > _availablePieces || _totalTransferPieces <= 0;

  Store? _getStore(String? id) {
    if (id == null) return null;
    final match = widget.availableStores.where((s) => s.id == id);
    return match.isNotEmpty ? match.first : null;
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
    if (result == null) return;
    final picked = result.gregorianDate;
    final eth = EthiopianCalendar.toEthiopian(picked.year, picked.month, picked.day);
    setState(() {
      _selectedDate = picked;
      _dateController.text = EthiopianCalendar.formatDisplay(
        eth,
        lang: widget.isAmharic ? 'am' : 'en',
      );
    });
  }

  Future<void> _confirmAndTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromStoreId == null || _toStoreId == null || _fromStoreId == _toStoreId) {
      setState(() {
        _errorMessage = widget.isAmharic
            ? 'እባክዎ የተለያዩ ምንጭ እና መዳረሻ መደብሮችን ይምረጡ'
            : 'Please select different source and destination stores';
      });
      return;
    }

    if (_selectedProduct == null) {
      setState(() {
        _errorMessage = widget.isAmharic ? 'እባክዎ የሚተላለፈውን ዕቃ ይምረጡ' : 'Please select a product to transfer';
      });
      return;
    }

    if (_totalTransferPieces <= 0) {
      setState(() {
        _errorMessage = widget.isAmharic ? 'የሚተላለፈው ብዛት ከአልቦ በላይ መሆን አለበት' : 'Transfer quantity must be > 0';
      });
      return;
    }

    if (_totalTransferPieces > _availablePieces) {
      setState(() {
        _errorMessage = widget.isAmharic
            ? 'በቂ ክምችት የለም! በምንጩ መደብር ያለው ${_availablePieces.toInt()} ፍሬ ብቻ ነው።'
            : 'Insufficient stock! Source store has only ${_availablePieces.toInt()} pieces available.';
      });
      return;
    }

    final fromStore = _getStore(_fromStoreId);
    final toStore = _getStore(_toStoreId);

    // Directly transfer without confirmation dialog
    setState(() {
      _isTransferring = true;
      _errorMessage = null;
    });

    try {
      final unitPrice = _selectedProduct!.unitPrice > 0 ? _selectedProduct!.unitPrice : _selectedProduct!.costPrice;
      final result = await ApiService.transferStock(
        fromStoreId: _fromStoreId!,
        toStoreId: _toStoreId!,
        fromStoreName: fromStore?.name ?? 'Store A',
        toStoreName: toStore?.name ?? 'Store B',
        productId: _selectedProduct!.id,
        productName: _selectedProduct!.productName,
        totalPieces: _totalTransferPieces,
        unitPrice: unitPrice,
        cartons: _enteredCartons,
        loosePieces: _enteredLoosePieces,
        pcsPerCarton: _pcsPerCarton,
        note: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        referenceNumber: _refNumberController.text.trim().isNotEmpty ? _refNumberController.text.trim() : null,
        transactionDate:
            '${_selectedDate.year.toString().padLeft(4, '0')}-'
            '${_selectedDate.month.toString().padLeft(2, '0')}-'
            '${_selectedDate.day.toString().padLeft(2, '0')}',
        createdBy: widget.currentUser.id,
      );

      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTransferring = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dialogBg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final inputFill = isDark ? AppTheme.darkSurfaceAlt : const Color(0xFFF8FAFC);
    final inputBorder = isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1);

    final validStores = widget.availableStores.where((s) => s.id != 'all').toList();
    final destinationStores = validStores.where((s) => s.id != _fromStoreId).toList();

    return Dialog(
      backgroundColor: dialogBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 490),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.swap_horiz_rounded, color: AppTheme.primaryBlue, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.isAmharic ? 'የመደብር ወደ መደብር ዝውውር' : 'Store-to-Store Transfer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C), fontWeight: FontWeight.bold),
                      ),
                    ),

                  // 2. From Store & To Store Route Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceAlt : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: inputBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // From Store (Source)
                        Row(
                          children: [
                            const Icon(Icons.upload_rounded, color: AppTheme.roseDanger, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              widget.isAmharic ? 'ከመደብር (ምንጭ) *' : 'From Store (Source) *',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          initialValue: _fromStoreId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? AppTheme.darkSurface : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: validStores.map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _fromStoreId = val;
                                if (_toStoreId == val) {
                                  final alt = validStores.where((s) => s.id != val).toList();
                                  _toStoreId = alt.isNotEmpty ? alt.first.id : null;
                                }
                              });
                              _loadSourceProducts(val);
                            }
                          },
                        ),
                        const SizedBox(height: 10),

                        // To Store (Destination)
                        Row(
                          children: [
                            const Icon(Icons.download_rounded, color: AppTheme.emeraldGreen, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              widget.isAmharic ? 'ወደ መደብር (መዳረሻ) *' : 'To Store (Destination) *',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          initialValue: _toStoreId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? AppTheme.darkSurface : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: destinationStores.map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _toStoreId = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Product Selection from Source Store
                  Text(
                    widget.isAmharic ? 'የሚተላለፈው ዕቃ *' : 'Select Product to Transfer *',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  if (_isLoadingSource)
                    const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                  else if (_sourceProducts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.isAmharic
                            ? 'በተመረጠው መደብር ውስጥ ምንም የሚተላለፍ ክምችት የለም።'
                            : 'No available stock in this source store to transfer.',
                        style: const TextStyle(fontSize: 12, color: AppTheme.roseDanger, fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    DropdownButtonFormField<InventoryProduct>(
                      initialValue: _selectedProduct,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: inputFill,
                        prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: _sourceProducts.map((p) {
                        final ctns = p.pcsPerCarton > 0 ? (p.currentQuantity / p.pcsPerCarton).floor() : 0;
                        return DropdownMenuItem(
                          value: p,
                          child: Text(
                            '${p.productName} (ክምችት: $ctns ctn / ${p.currentQuantity.toInt()} pcs)',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (p) {
                        if (p != null) {
                          setState(() => _selectedProduct = p);
                        }
                      },
                    ),
                  const SizedBox(height: 12),

                  // 4. Quantity: Cartons & Loose Pieces
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LanguageService.t('carton'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _cartonsController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: '1',
                                filled: true,
                                fillColor: inputFill,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isAmharic ? 'ነጠላ ፍሬ (Loose)' : 'Loose Pieces',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _piecesController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: '0',
                                filled: true,
                                fillColor: inputFill,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 5. Stock Preview Box
                  if (_selectedProduct != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isInsufficientStock
                            ? const Color(0xFFFEF2F2)
                            : (isDark ? AppTheme.darkSurfaceAlt : const Color(0xFFECFDF5)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isInsufficientStock ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.isAmharic ? 'የምንጭ መደብር ያለ ክምችት:' : 'Source Available Stock:',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${_availablePieces.toInt()} pcs',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.isAmharic ? 'የሚተላለፍ ጠቅላላ ፍሬ:' : 'Total Transfer Pieces:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _isInsufficientStock ? AppTheme.roseDanger : AppTheme.primaryBlue,
                                ),
                              ),
                              Text(
                                '${_totalTransferPieces.toInt()} pcs',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: _isInsufficientStock ? AppTheme.roseDanger : AppTheme.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.isAmharic ? 'ከዝውውር በኋላ የሚቀረው:' : 'Remaining in Source Store:',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${(_availablePieces - _totalTransferPieces).toInt()} pcs',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: (_availablePieces - _totalTransferPieces) >= 0
                                      ? AppTheme.emeraldGreen
                                      : AppTheme.roseDanger,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),

                  // 6. Date, Ref Number, and Note
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: LanguageService.t('date'),
                              suffixIcon: const Icon(Icons.calendar_month, size: 18),
                              filled: true,
                              fillColor: inputFill,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(_dateController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _refNumberController,
                          decoration: InputDecoration(
                            labelText: widget.isAmharic ? 'ማጣቀሻ (Ref #)' : 'Reference #',
                            filled: true,
                            fillColor: inputFill,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: LanguageService.t('note'),
                      hintText: widget.isAmharic ? 'የዝውውር ምክንያት ወይም ማስታወሻ...' : 'Reason for transfer / note...',
                      filled: true,
                      fillColor: inputFill,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 18),

                  // 7. Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isTransferring ? null : () => Navigator.pop(context),
                        child: Text(LanguageService.t('cancel')),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: (_isTransferring || _isInsufficientStock || _sourceProducts.isEmpty)
                            ? null
                            : _confirmAndTransfer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _isTransferring
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.swap_horiz_rounded, size: 18),
                        label: Text(
                          _isTransferring
                              ? (widget.isAmharic ? 'በማስተላለፍ ላይ...' : 'Transferring...')
                              : (widget.isAmharic ? 'ክምችት አስተላልፍ' : 'Transfer Stock'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
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

