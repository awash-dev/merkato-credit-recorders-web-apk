import 'dart:convert';

class AppUser {
  final String id;
  final String name;
  final String? email;
  final String? phone; // login identifier (e.g. +2519...)
  final String role; // 'admin' | 'storekeeper' | 'sales'
  final String? storeId;
  final String? storeName;
  final List<String> assignedStoreIds;
  final bool active;

  AppUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.role,
    this.storeId,
    this.storeName,
    this.assignedStoreIds = const [],
    this.active = true,
  });

  bool get isAdmin => role == 'admin';
  bool get isStorekeeper => role == 'storekeeper';
  bool get isSales => role == 'sales';

  /// Whether user can switch between stores (multi-store access with one login)
  bool get canSwitchStores =>
      isAdmin ||
      assignedStoreIds.length > 1 ||
      assignedStoreIds.contains('all') ||
      isStorekeeper ||
      isSales;

  bool canAccessStore(String? targetStoreId) {
    if (isAdmin) return true;
    if (targetStoreId == null || targetStoreId == 'all') return true;
    if (assignedStoreIds.contains('all') || assignedStoreIds.contains(targetStoreId)) return true;
    if (storeId == targetStoreId) return true;
    if (assignedStoreIds.isEmpty) return true; // Open to switchable stores
    return false;
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    List<String> parsedStoreIds = [];
    final rawAssigned = json['assigned_stores'] ?? json['assignedStores'] ?? json['store_ids'];
    if (rawAssigned is List) {
      parsedStoreIds = rawAssigned.map((e) => e.toString()).toList();
    } else if (rawAssigned is String && rawAssigned.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawAssigned);
        if (decoded is List) {
          parsedStoreIds = decoded.map((e) => e.toString()).toList();
        } else {
          parsedStoreIds = rawAssigned
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {
        parsedStoreIds = rawAssigned
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    final sId = json['storeId']?.toString() ?? json['store_id']?.toString();
    if (sId != null && sId.isNotEmpty && !parsedStoreIds.contains(sId)) {
      parsedStoreIds.add(sId);
    }

    return AppUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? 'storekeeper',
      storeId: sId,
      storeName: json['storeName']?.toString() ?? json['store_name']?.toString(),
      assignedStoreIds: parsedStoreIds,
      active: json['active'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'storeId': storeId,
      'storeName': storeName,
      'assigned_stores': jsonEncode(assignedStoreIds),
      'active': active,
    };
  }
}
