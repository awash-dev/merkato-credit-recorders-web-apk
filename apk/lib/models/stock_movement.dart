class StockMovement {
  final String id;
  final String? storeId;
  final String productId;
  final String movementType; // 'IN' or 'OUT'
  final double quantity; // in base units (pieces)
  final String transactionUnit;
  final double conversionFactor; // pcs_per_carton
  final double baseQuantity;
  final double previousStock;
  final double newStock;
  final double unitPrice;
  final double totalPrice;
  final String transactionDate;
  final String? sourceType;
  final String? sourceId; // Supplier
  final String? destination; // Customer / Destination
  final String? referenceNumber;
  final String? note;
  final String? createdBy;
  final String? userName;
  final String? productName;
  final String? storeName;
  final DateTime? createdAt;

  StockMovement({
    required this.id,
    this.storeId,
    required this.productId,
    required this.movementType,
    required this.quantity,
    this.transactionUnit = 'Pcs',
    this.conversionFactor = 1,
    required this.baseQuantity,
    required this.previousStock,
    required this.newStock,
    required this.unitPrice,
    required this.totalPrice,
    required this.transactionDate,
    this.sourceType,
    this.sourceId,
    this.destination,
    this.referenceNumber,
    this.note,
    this.createdBy,
    this.userName,
    this.productName,
    this.storeName,
    this.createdAt,
  });

  bool get isIn => movementType.toUpperCase() == 'IN';
  bool get isOut => movementType.toUpperCase() == 'OUT';

  DateTime? get date {
    try {
      return DateTime.parse(transactionDate);
    } catch (_) {
      return createdAt;
    }
  }

  double get totalPieces => quantity;
  double get quantityCartons => conversionFactor > 0 ? (quantity / conversionFactor).floorToDouble() : 0.0;
  String? get party => sourceId ?? destination;
  String? get notes => note;

  int get cartons {
    if (conversionFactor <= 0) return 0;
    return (quantity / conversionFactor).floor();
  }

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    double parseDouble(dynamic val, [double def = 0.0]) {
      if (val == null) return def;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? def;
    }

    return StockMovement(
      id: json['id']?.toString() ?? '',
      storeId: json['store_id']?.toString(),
      productId: json['product_id']?.toString() ?? '',
      movementType: json['movement_type']?.toString().toUpperCase() ?? 'IN',
      quantity: parseDouble(json['quantity']),
      transactionUnit: json['transaction_unit']?.toString() ?? 'Pcs',
      conversionFactor: parseDouble(json['conversion_factor'], 1.0),
      baseQuantity: parseDouble(json['base_quantity']),
      previousStock: parseDouble(json['previous_stock']),
      newStock: parseDouble(json['new_stock']),
      unitPrice: parseDouble(json['unit_price']),
      totalPrice: parseDouble(json['total_price']),
      transactionDate: json['transaction_date']?.toString() ?? '',
      sourceType: json['source_type']?.toString(),
      sourceId: json['source_id']?.toString(),
      destination: json['destination']?.toString(),
      referenceNumber: json['reference_number']?.toString(),
      note: json['note']?.toString(),
      createdBy: json['created_by']?.toString(),
      userName: json['user_name']?.toString(),
      productName: json['product_name']?.toString() ?? json['productName']?.toString(),
      storeName: json['store_name']?.toString() ?? json['storeName']?.toString(),
      createdAt: parseDate(json['created_at']),
    );
  }
}
