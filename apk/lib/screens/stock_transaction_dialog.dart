import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:et_date_picker/et_date_picker.dart';
import '../models/inventory_product.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/ethiopian_calendar.dart';

/// Reusable Store Entry Dialog for Stock In (+) and Stock Out (-)
///
/// Supports:
/// - Instant auto-fill of saved DB records for existing products (all fields editable)
/// - Seamless auto-save / auto-registration for new products directly on Stock In
///   without forcing the user to open a separate registration form
/// - Smart merging into existing stock balances for recorded products
/// - Real-time calculation of Total Pieces and Total Value
/// - Strict protection against negative inventory on Stock Out
class StockTransactionDialog extends StatefulWidget {
  final AppUser currentUser;
  final String? activeStoreId;
  final List<InventoryProduct> availableProducts;
  final InventoryProduct? preselectedProduct;
  final String initialMovementType; // 'IN' or 'OUT'
  final bool isAmharic;

  const StockTransactionDialog({
    super.key,
    required this.currentUser,
    this.activeStoreId,
    required this.availableProducts,
    this.preselectedProduct,
    this.initialMovementType = 'IN',
    this.isAmharic = true,
  });

  @override
  State<StockTransactionDialog> createState() => _StockTransactionDialogState();
}

class _StockTransactionDialogState extends State<StockTransactionDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _movementType; // 'IN' or 'OUT'
  String _packaging = 'Carton'; // 'Carton' or 'Piece'
  InventoryProduct? _selectedProduct;

  final _productNameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _pcsPerCartonController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();
  final _partyController = TextEditingController();
  final _notesController = TextEditingController();
  final _dateController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  bool _isSaving = false;
  String? _errorMessage;

  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _movementType = widget.initialMovementType;
    final now = DateTime.now();
    _selectedDate = now;
    final eth = EthiopianCalendar.toEthiopian(now.year, now.month, now.day);
    _dateController.text = EthiopianCalendar.formatDisplay(
      eth,
      lang: widget.isAmharic ? 'am' : 'en',
    );

    _quantityController.addListener(_onFieldChanged);
    _pcsPerCartonController.addListener(_onFieldChanged);
    _unitPriceController.addListener(_onFieldChanged);

    if (widget.preselectedProduct != null) {
      _applyProduct(widget.preselectedProduct!);
    }
  }

  @override
  void dispose() {
    _quantityController.removeListener(_onFieldChanged);
    _pcsPerCartonController.removeListener(_onFieldChanged);
    _unitPriceController.removeListener(_onFieldChanged);

    _productNameController.dispose();
    _quantityController.dispose();
    _pcsPerCartonController.dispose();
    _unitPriceController.dispose();
    _partyController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {});
  }

  Future<void> _pickEthiopianDate() async {
    final result = await showEthiopianDatePickerDialog(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      showSelectedDatePreview: true,
      useEthiopicNumerals: widget.isAmharic,
      cancelText: widget.isAmharic ? 'ሰርዝ' : 'Cancel',
      confirmText: widget.isAmharic ? 'ይሁን' : 'OK',
    );
    if (result == null) return;
    final picked = result.gregorianDate;
    final eth = EthiopianCalendar.toEthiopian(
      picked.year,
      picked.month,
      picked.day,
    );
    setState(() {
      _selectedDate = picked;
      _dateController.text = EthiopianCalendar.formatDisplay(
        eth,
        lang: widget.isAmharic ? 'am' : 'en',
      );
    });
  }

  /// Populate fields from existing product record and fetch latest DB state
  void _applyProduct(InventoryProduct prod, {bool fetchFromDb = true}) async {
    final pcs = prod.pcsPerCarton > 0
        ? (prod.pcsPerCarton % 1 == 0
            ? prod.pcsPerCarton.toInt().toString()
            : prod.pcsPerCarton.toString())
        : '1';

    final price = _movementType == 'OUT'
        ? (prod.storekeeperPrice > 0
            ? prod.storekeeperPrice
            : (prod.unitPrice > 0 ? prod.unitPrice : prod.costPrice))
        : (prod.costPrice > 0
            ? prod.costPrice
            : (prod.storekeeperPrice > 0 ? prod.storekeeperPrice : prod.unitPrice));

    setState(() {
      _selectedProduct = prod;
      _productNameController.text = prod.productName;
      _pcsPerCartonController.text = pcs;
      _unitPriceController.text = price > 0
          ? (price % 1 == 0 ? price.toInt().toString() : price.toStringAsFixed(2))
          : '0.00';
      if (_partyController.text.isEmpty &&
          prod.supplierName != null &&
          prod.supplierName!.isNotEmpty) {
        _partyController.text = prod.supplierName!;
      }
      _errorMessage = null;
    });

    if (fetchFromDb && prod.id.isNotEmpty) {
      try {
        final fresh = await ApiService.getProductById(prod.id);
        if (fresh != null && mounted && _selectedProduct?.id == prod.id) {
          final freshPcs = fresh.pcsPerCarton > 0
              ? (fresh.pcsPerCarton % 1 == 0
                  ? fresh.pcsPerCarton.toInt().toString()
                  : fresh.pcsPerCarton.toString())
              : '1';
          final freshPrice = _movementType == 'OUT'
              ? (fresh.storekeeperPrice > 0
                  ? fresh.storekeeperPrice
                  : (fresh.unitPrice > 0 ? fresh.unitPrice : fresh.costPrice))
              : (fresh.costPrice > 0
                  ? fresh.costPrice
                  : (fresh.storekeeperPrice > 0 ? fresh.storekeeperPrice : fresh.unitPrice));

          setState(() {
            _selectedProduct = fresh;
            _productNameController.text = fresh.productName;
            _pcsPerCartonController.text = freshPcs;
            if (_unitPriceController.text.isEmpty ||
                _unitPriceController.text == '0.00' ||
                _unitPriceController.text == '0') {
              _unitPriceController.text = freshPrice > 0
                  ? (freshPrice % 1 == 0
                      ? freshPrice.toInt().toString()
                      : freshPrice.toStringAsFixed(2))
                  : '0.00';
            }
          });
        }
      } catch (_) {}
    }
  }

  void _onProductNameChanged(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      setState(() {
        _selectedProduct = null;
      });
      return;
    }

    final match = widget.availableProducts.where(
      (p) =>
          p.productName.trim().toLowerCase() == clean ||
          LanguageService.translateProduct(p.productName).trim().toLowerCase() == clean,
    );

    if (match.isNotEmpty) {
      _applyProduct(match.first);
      return;
    }

    // Try live lookup in DB
    try {
      final dbProd = await ApiService.getProductByName(clean, widget.activeStoreId);
      if (dbProd != null && mounted && _productNameController.text.trim().toLowerCase() == clean) {
        _applyProduct(dbProd, fetchFromDb: false);
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _selectedProduct = null;
      });
    }
  }

  // --- Calculations ---
  double get _enteredQty => double.tryParse(_quantityController.text.trim()) ?? 0.0;

  double get _pcsPerCarton {
    final v = double.tryParse(_pcsPerCartonController.text.trim()) ?? 1.0;
    return v > 0 ? v : 1.0;
  }

  /// Total Pieces = Quantity × Pieces per Carton (if Carton), or Quantity (if Piece)
  double get _totalPieces {
    if (_packaging == 'Piece') {
      return _enteredQty;
    } else {
      return _enteredQty * _pcsPerCarton;
    }
  }

  /// Unit Price per Piece
  double get _unitPrice =>
      double.tryParse(_unitPriceController.text.trim()) ?? 0.0;

  /// Available pieces on-hand
  double get _availablePieces =>
      _selectedProduct != null ? _selectedProduct!.currentQuantity : 0.0;

  /// Available cartons on-hand
  int get _availableCartons {
    if (_selectedProduct == null) return 0;
    final factor = _selectedProduct!.pcsPerCarton > 0
        ? _selectedProduct!.pcsPerCarton
        : 1.0;
    return (_selectedProduct!.currentQuantity / factor).floor();
  }

  bool get _isStockOut => _movementType == 'OUT';

  /// Validation: Stock Out cannot exceed available pieces
  bool get _isStockOutExceeded =>
      _isStockOut && (_selectedProduct == null || _totalPieces > _availablePieces);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final trimmedName = _productNameController.text.trim();
    if (trimmedName.isEmpty) {
      setState(() {
        _errorMessage = widget.isAmharic
            ? 'እባክዎ የዕቃ ስም ያስገቡ'
            : 'Please enter a product name';
      });
      return;
    }

    if (_isStockOut && _selectedProduct == null) {
      setState(() {
        _errorMessage = widget.isAmharic
            ? 'ምርቱ በመደብር ውስጥ አልተገኘም። ወጪ ለማድረግ አስቀድሞ ገቢ መመዝገብ አለበት።'
            : 'Product not found in store inventory. Must stock in before stocking out.';
      });
      return;
    }

    if (_totalPieces <= 0) {
      setState(() {
        _errorMessage = widget.isAmharic
            ? 'እባክዎ ትክክለኛ የብዛት መጠን ያስገቡ'
            : 'Please enter a valid quantity';
      });
      return;
    }

    if (_isStockOutExceeded) {
      setState(() {
        _errorMessage = widget.isAmharic
            ? 'በቂ እቃ የለም! በመደብሩ ያለው መጠን ${_availablePieces.toInt()} ፍሬ ብቻ ነው። ከዚህ በላይ ማውጣት አይቻልም።'
            : 'Insufficient stock! Available quantity: ${_availablePieces.toInt()} pieces. Cannot exceed available inventory.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final cartons = _packaging == 'Carton' ? _enteredQty : (_totalPieces / _pcsPerCarton);
      final loosePieces = _packaging == 'Piece' ? _enteredQty : 0.0;

      final updated = await ApiService.recordStockMovement(
        productId: _selectedProduct?.id,
        productName: trimmedName,
        movementType: _movementType,
        totalPieces: _totalPieces,
        unitPrice: _unitPrice,
        cartons: cartons,
        loosePieces: loosePieces,
        pcsPerCarton: _pcsPerCarton,
        party: _partyController.text.trim().isNotEmpty ? _partyController.text.trim() : null,
        note: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        transactionDate:
            '${_selectedDate.year.toString().padLeft(4, '0')}-'
            '${_selectedDate.month.toString().padLeft(2, '0')}-'
            '${_selectedDate.day.toString().padLeft(2, '0')}',
        storeId: _selectedProduct?.storeId ?? widget.activeStoreId,
        createdBy: widget.currentUser.id,
      );

      if (mounted) {
        Navigator.pop(context, updated);
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
    const inputFillColor = Color(0xFFF8FAFC);
    const inputBorderColor = Color(0xFFE2E8F0);
    const primaryTextColor = Color(0xFF0F172A);
    const labelTextColor = Color(0xFF475569);

    final canSubmit = !_isSaving &&
        _productNameController.text.trim().isNotEmpty &&
        _totalPieces > 0 &&
        !(_isStockOut && (_selectedProduct == null || _isStockOutExceeded));

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- 1. MODAL TITLE HEADER ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isStockOut ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            size: 22,
                            color: _isStockOut ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.isAmharic ? 'የዕቃ መዝገብ' : 'Store Entry',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: primaryTextColor,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // --- 2. STOCK MOVEMENT BUTTONS (Stock In / Stock Out) ---
                  Text(
                    widget.isAmharic ? 'የዕቃ ዝውውር' : 'Stock Movement',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: labelTextColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Stock In (+) Button
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _movementType = 'IN';
                              if (_selectedProduct != null) {
                                final p = _selectedProduct!.costPrice > 0
                                    ? _selectedProduct!.costPrice
                                    : _selectedProduct!.unitPrice;
                                _unitPriceController.text = p > 0
                                    ? (p % 1 == 0 ? p.toInt().toString() : p.toStringAsFixed(2))
                                    : '0.00';
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: !_isStockOut ? const Color(0xFF2563EB) : inputFillColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: !_isStockOut ? const Color(0xFF2563EB) : inputBorderColor,
                                width: !_isStockOut ? 1.5 : 1.0,
                              ),
                              boxShadow: !_isStockOut
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  size: 16,
                                  color: !_isStockOut ? Colors.white : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.isAmharic ? 'ዕቃ ገቢ (+)' : 'Stock In (+)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: !_isStockOut ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Stock Out (-) Button
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _movementType = 'OUT';
                              if (_selectedProduct != null) {
                                final p = _selectedProduct!.unitPrice > 0
                                    ? _selectedProduct!.unitPrice
                                    : _selectedProduct!.costPrice;
                                _unitPriceController.text = p > 0
                                    ? (p % 1 == 0 ? p.toInt().toString() : p.toStringAsFixed(2))
                                    : '0.00';
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _isStockOut ? const Color(0xFFDC2626) : inputFillColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _isStockOut ? const Color(0xFFDC2626) : inputBorderColor,
                                width: _isStockOut ? 1.5 : 1.0,
                              ),
                              boxShadow: _isStockOut
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFDC2626).withValues(alpha: 0.25),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.remove_circle_outline,
                                  size: 16,
                                  color: _isStockOut ? Colors.white : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.isAmharic ? 'ዕቃ ወጪ (-)' : 'Stock Out (-)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _isStockOut ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Error Banner
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // --- 3. ITEM SELECTION (Searchable Product Input) ---
                  Text(
                    widget.isAmharic ? 'የዕቃ ስም' : 'Item Name',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: labelTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Autocomplete<InventoryProduct>(
                    displayStringForOption: (prod) => prod.productName,
                    initialValue: TextEditingValue(text: _productNameController.text),
                    optionsBuilder: (textEditingValue) {
                      final q = textEditingValue.text.trim().toLowerCase();
                      if (q.isEmpty) return const Iterable.empty();
                      return widget.availableProducts.where(
                        (p) =>
                            p.productName.toLowerCase().contains(q) ||
                            LanguageService.translateProduct(p.productName).toLowerCase().contains(q),
                      );
                    },
                    onSelected: (prod) {
                      _applyProduct(prod);
                    },
                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      if (_productNameController.text.isNotEmpty && controller.text.isEmpty) {
                        controller.text = _productNameController.text;
                      }
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        onEditingComplete: onEditingComplete,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.isAmharic ? 'ዕቃ ይፈልጉ ወይም አዲስ ስም ያስገቡ...' : 'Search product or enter new name...',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                          suffixIcon: _productNameController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    controller.clear();
                                    _productNameController.clear();
                                    setState(() {
                                      _selectedProduct = null;
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: inputBorderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: inputBorderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onChanged: (val) {
                          _productNameController.text = val;
                          _onProductNameChanged(val);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // --- 4. CURRENT AVAILABLE STOCK PANEL (For Existing Products) ---
                  if (_selectedProduct != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: inputBorderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedProduct!.productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: primaryTextColor,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _availablePieces > 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _availablePieces > 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Text(
                                  '$_availableCartons ${widget.isAmharic ? "ካርቶን" : "Cartons"} (${_availablePieces.toInt()} ${widget.isAmharic ? "ፍሬ" : "Pcs"})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: _availablePieces > 0 ? const Color(0xFF047857) : const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 14, color: Color(0xFFE2E8F0)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${widget.isAmharic ? "ፍሬ በካርቶን" : "Pieces/Carton"}: ${_selectedProduct!.pcsPerCarton.toInt()}',
                                style: const TextStyle(fontSize: 11, color: labelTextColor, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${widget.isAmharic ? "የአንዱ ዋጋ" : "Unit Price"}: ${_currencyFormat.format(_selectedProduct!.unitPrice > 0 ? _selectedProduct!.unitPrice : _selectedProduct!.costPrice)} ${widget.isAmharic ? "ብር" : "ETB"}',
                                style: const TextStyle(fontSize: 11, color: labelTextColor, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // --- 5. QUANTITY & PACKAGING SELECTION ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quantity input
                      Expanded(
                        flex: 11,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isAmharic ? 'ብዛት' : 'Quantity',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: labelTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _quantityController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryTextColor),
                              decoration: InputDecoration(
                                hintText: '1',
                                filled: true,
                                fillColor: inputFillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: inputBorderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: inputBorderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Packaging selection (Carton / Piece)
                      Expanded(
                        flex: 13,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isAmharic ? 'ማሸጊያ' : 'Packaging',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: labelTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 48,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: inputFillColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: inputBorderColor),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(() => _packaging = 'Carton'),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: _packaging == 'Carton' ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                          boxShadow: _packaging == 'Carton'
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.05),
                                                    blurRadius: 2,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Text(
                                          widget.isAmharic ? 'ካርቶን' : 'Carton',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _packaging == 'Carton' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(() => _packaging = 'Piece'),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: _packaging == 'Piece' ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                          boxShadow: _packaging == 'Piece'
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.05),
                                                    blurRadius: 2,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Text(
                                          widget.isAmharic ? 'ፍሬ' : 'Piece',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _packaging == 'Piece' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Pieces per Carton Input (shown only when packaging is Carton)
                  if (_packaging == 'Carton') ...[
                    Text(
                      widget.isAmharic ? 'ፍሬ በካርቶን' : 'Pieces / Carton',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: labelTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _pcsPerCartonController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                      decoration: InputDecoration(
                        hintText: '1',
                        filled: true,
                        fillColor: inputFillColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: inputBorderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: inputBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Strict Stock Out Protection Error
                  if (_isStockOutExceeded) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedProduct == null
                                  ? (widget.isAmharic
                                      ? 'ምርቱ በመደብር ውስጥ አልተገኘም (የሌለ እቃ ማውጣት አይቻልም)'
                                      : 'Product not found in store (cannot stock out non-existent item)')
                                  : (widget.isAmharic
                                      ? 'በቂ እቃ የለም! በመደብሩ ያለው መጠን ${_availablePieces.toInt()} ፍሬ ብቻ ነው። ከዚህ በላይ ማውጣት አይቻልም።'
                                      : 'Insufficient stock! Available quantity: ${_availablePieces.toInt()} pieces. Cannot exceed available inventory.'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF991B1B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Date and Note
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date with calendar selector
                      Expanded(
                        flex: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isAmharic ? 'ቀን' : 'Date',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: labelTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: _pickEthiopianDate,
                              borderRadius: BorderRadius.circular(8),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  suffixIcon: const Icon(Icons.calendar_month, size: 18),
                                  filled: true,
                                  fillColor: inputFillColor,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: inputBorderColor),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 11,
                                  ),
                                ),
                                child: Text(
                                  _dateController.text,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: primaryTextColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Optional Note field
                      Expanded(
                        flex: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isAmharic ? 'ማስታወሻ' : 'Note',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: labelTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _notesController,
                              style: const TextStyle(fontSize: 12.5, color: primaryTextColor),
                              decoration: InputDecoration(
                                hintText: widget.isAmharic ? 'ምሳሌ፡ ደረሰኝ ቁጥር' : 'e.g. INV-1049',
                                filled: true,
                                fillColor: inputFillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: inputBorderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: inputBorderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- 8. ACTION BUTTONS (Save & Cancel) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: Text(
                          widget.isAmharic ? 'ይቅር' : 'Cancel',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: canSubmit ? _submit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isStockOut ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF94A3B8),
                          disabledForegroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check, size: 16),
                        label: Text(
                          _isSaving
                              ? (widget.isAmharic ? 'በመመዝገብ ላይ...' : 'Saving...')
                              : (_isStockOut
                                  ? (widget.isAmharic ? 'ወጪ መዝግብ' : 'Save Stock Out')
                                  : (widget.isAmharic ? 'ገቢ መዝግብ' : 'Save Stock In')),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
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
