import 'package:flutter_test/flutter_test.dart';
import 'package:apk/models/user.dart';
import 'package:apk/models/stock_movement.dart';
import 'package:apk/models/store.dart';

void main() {
  group('Storekeeper Multi-Store Assignment & Access Tests', () {
    test('Storekeeper with multiple assigned stores can access each assigned store', () {
      final user = AppUser(
        id: 'user_sk_1',
        name: 'Abebe Kebede',
        role: 'storekeeper',
        assignedStoreIds: ['store_semera_wh', 'store_awash_wh', 'store_mille_branch'],
      );

      expect(user.canSwitchStores, isTrue);
      expect(user.canAccessStore('store_semera_wh'), isTrue);
      expect(user.canAccessStore('store_awash_wh'), isTrue);
      expect(user.canAccessStore('store_mille_branch'), isTrue);
      expect(user.canAccessStore('unassigned_store_99'), isFalse);
      expect(user.canAccessStore('all'), isTrue);
    });

    test('Admin user can access any store location', () {
      final admin = AppUser(
        id: 'admin_1',
        name: 'Super Admin',
        role: 'admin',
        assignedStoreIds: [],
      );

      expect(admin.isAdmin, isTrue);
      expect(admin.canAccessStore('store_semera_wh'), isTrue);
      expect(admin.canAccessStore('any_random_store'), isTrue);
      expect(admin.canAccessStore('all'), isTrue);
    });

    test('User with assignedStoreIds json parsing works from API/DB', () {
      final json = {
        'id': 'sk_101',
        'name': 'Store Manager',
        'role': 'storekeeper',
        'assignedStores': ['store_1', 'store_2'],
      };

      final parsed = AppUser.fromJson(json);
      expect(parsed.assignedStoreIds, containsAll(['store_1', 'store_2']));
      expect(parsed.canAccessStore('store_1'), isTrue);
      expect(parsed.canAccessStore('store_2'), isTrue);
      expect(parsed.canAccessStore('store_3'), isFalse);
    });
  });

  group('StockMovement Model & Carton Conversion Tests', () {
    test('Correctly computes cartons, pieces, party, and dates', () {
      final movement = StockMovement(
        id: 'mov_1',
        storeId: 'store_1',
        productId: 'prod_1',
        movementType: 'IN',
        quantity: 125,
        conversionFactor: 24, // 24 pcs per carton
        baseQuantity: 125,
        previousStock: 0,
        newStock: 125,
        unitPrice: 10,
        totalPrice: 1250,
        transactionDate: '2026-11-19T10:30:00.000Z',
        sourceId: 'Global Importers PLC',
        referenceNumber: 'REF-INV-2026',
        note: 'Incoming container shipment',
        createdBy: 'abebe',
        productName: 'Cooking Oil 5L',
        storeName: 'Semera Main Warehouse',
      );

      expect(movement.isIn, isTrue);
      expect(movement.isOut, isFalse);
      expect(movement.totalPieces, equals(125));
      expect(movement.cartons, equals(5)); // (125 / 24).floor() = 5 cartons
      expect(movement.quantityCartons, equals(5.0));
      expect(movement.party, equals('Global Importers PLC'));
      expect(movement.notes, equals('Incoming container shipment'));
      expect(movement.date, isNotNull);
      expect(movement.date!.year, equals(2026));
      expect(movement.date!.month, equals(11));
      expect(movement.date!.day, equals(19));
    });

    test('Outbound transfer movement is properly identified', () {
      final transfer = StockMovement(
        id: 'mov_tr_1',
        storeId: 'store_from',
        productId: 'prod_1',
        movementType: 'TRANSFER_OUT',
        quantity: 48,
        conversionFactor: 12,
        baseQuantity: 48,
        previousStock: 100,
        newStock: 52,
        unitPrice: 15,
        totalPrice: 720,
        transactionDate: '2026-11-19',
        destination: 'Awash Retail Branch',
        referenceNumber: 'TR-2026-001',
      );

      expect(transfer.movementType.contains('TRANSFER'), isTrue);
      expect(transfer.totalPieces, equals(48));
      expect(transfer.cartons, equals(4)); // 48 / 12 = 4
      expect(transfer.party, equals('Awash Retail Branch'));
    });
  });

  group('Store Model Tests', () {
    test('Stores serialization and formatting', () {
      final store = Store(id: 'st_1', name: 'Main Semera Store', code: 'SEM');
      expect(store.id, equals('st_1'));
      expect(store.name, equals('Main Semera Store'));
      expect(store.code, equals('SEM'));

      final json = store.toJson();
      final revived = Store.fromJson(json);
      expect(revived.id, equals(store.id));
      expect(revived.name, equals(store.name));
      expect(revived.code, equals(store.code));
    });
  });
}
