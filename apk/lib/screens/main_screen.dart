import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../models/store.dart';
import '../models/ledger_record.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/app_settings_service.dart';
import '../services/ethiopian_calendar.dart';
import 'login_screen.dart';
import 'record_form_dialog.dart';
import 'statement_screen.dart';
import '../models/inventory_product.dart';
import 'new_product_dialog.dart';
import 'stock_transaction_dialog.dart';
import 'product_history_dialog.dart';
import 'edit_product_dialog.dart';
import 'admin_users_screen.dart';
import '../widgets/telebirr_background.dart';

class MainScreen extends StatefulWidget {
  final AppUser currentUser;

  const MainScreen({super.key, required this.currentUser});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  // Language / Translator state backed by LanguageService
  bool get _isAmharic => LanguageService.isAmharic;

  // Tabs: 0: Customer, 1: Supplier, 2: Delala, 3: Stocks
  int _currentTabIndex = 0;
  List<Store> _stores = [];
  String? _selectedStoreId;
  List<LedgerRecord> _records = [];
  List<InventoryProduct> _inventoryProducts = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Records collapsed by default (tap header to expand) — mobile friendly cards
  final Set<String> _expandedRecordIds = <String>{};

  void _toggleRecordExpanded(String id) {
    setState(() {
      if (!_expandedRecordIds.remove(id)) {
        _expandedRecordIds.add(id);
      }
    });
  }

  // Products collapsed by default (tap header to expand) — mobile friendly cards
  final Set<String> _expandedProductIds = <String>{};

  void _toggleProductExpanded(String id) {
    setState(() {
      if (!_expandedProductIds.remove(id)) {
        _expandedProductIds.add(id);
      }
    });
  }

  @override
  void initState() {
    super.initState();

    // Admin sees all 4 tabs: Customer, Supplier, Delala, Store (opens on Customer).
    // Storekeepers only have store pages, so they open straight on the Store tab
    // and the party/delala tabs are hidden from the bottom bar.
    _currentTabIndex =
        (widget.currentUser.isStorekeeper || widget.currentUser.isSales)
            ? 3
            : 0;
    if (widget.currentUser.isStorekeeper || widget.currentUser.isSales) {
      // The store comes from the signed-in user row in the database; when it
      // is missing we keep null instead of inventing a store id.
      _selectedStoreId = widget.currentUser.storeId;
    } else {
      _selectedStoreId = 'all';
    }

    LanguageService.currentLanguage.addListener(_onLanguageChanged);
    _loadLanguagePreference();
    _loadStoresAndRecords();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLanguagePreference() async {
    try {
      await LanguageService.init();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    LanguageService.currentLanguage.removeListener(_onLanguageChanged);
    _searchController.dispose();
    super.dispose();
  }

  String get _currentTabType {
    switch (_currentTabIndex) {
      case 0:
        return 'customer';
      case 1:
        return 'supplier';
      case 2:
        return 'delala';
      case 3:
        return 'stock';
      default:
        return 'customer';
    }
  }

  String get _currentTabLabel {
    if (_isAmharic) {
      switch (_currentTabIndex) {
        case 0:
          return 'የደንበኛ ብድር';
        case 1:
          return 'የአቅራቢ ብድር';
        case 2:
          return 'የደላላ ሂሳብ';
        case 3:
          return 'የመደብር እቃዎች';
        default:
          return 'የደንበኛ ብድር';
      }
    }
    switch (_currentTabIndex) {
      case 0:
        return 'Customer Credit';
      case 1:
        return 'Supplier Credit';
      case 2:
        return 'Delala Ledger';
      case 3:
        return 'Store Inventory';
      default:
        return 'Customer Credit';
    }
  }

  /// Store name shown in the header. Resolved from the signed-in user row and
  /// the `stores` table — never from a hardcoded store list.
  String get _activeStoreLabel {
    if (_selectedStoreId != null && _selectedStoreId != 'all') {
      final match = _stores.where((s) => s.id == _selectedStoreId);
      if (match.isNotEmpty) return match.first.name;
    }
    if (_selectedStoreId == 'all') {
      return _isAmharic ? 'ሁሉም መደብሮች' : 'All Stores (Central)';
    }

    final ownName = widget.currentUser.storeName;
    if (ownName != null && ownName.isNotEmpty) return ownName;

    final match = _stores.where((s) => s.id == widget.currentUser.storeId);
    return match.isNotEmpty ? match.first.name : (_isAmharic ? 'መደብር አልተመረጠም' : 'No store assigned');
  }

  Future<void> _loadStoresAndRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final stores = await ApiService.getStores();
      String? targetStoreId = _selectedStoreId;
      if (widget.currentUser.isStorekeeper || widget.currentUser.isSales) {
        targetStoreId = _selectedStoreId ?? widget.currentUser.storeId;
        if ((targetStoreId == null || targetStoreId.isEmpty) &&
            stores.isNotEmpty) {
          targetStoreId = stores.first.id;
        }
        _selectedStoreId = targetStoreId;
      }
      final records = await ApiService.getRecords(storeId: targetStoreId);
      final inventoryProducts = await ApiService.getInventoryProducts(
        storeId: targetStoreId,
      );
      if (mounted) {
        setState(() {
          _stores = stores;
          _records = records;
          _inventoryProducts = inventoryProducts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  Future<void> _reloadRecordsOnly() async {
    try {
      String? targetStoreId = _selectedStoreId;
      if (widget.currentUser.isStorekeeper || widget.currentUser.isSales) {
        targetStoreId = _selectedStoreId ?? widget.currentUser.storeId;
        if ((targetStoreId == null || targetStoreId.isEmpty) &&
            _stores.isNotEmpty) {
          targetStoreId = _stores.first.id;
        }
        _selectedStoreId = targetStoreId;
      }
      final records = await ApiService.getRecords(storeId: targetStoreId);
      final inventoryProducts = await ApiService.getInventoryProducts(
        storeId: targetStoreId,
      );
      if (mounted) {
        setState(() {
          _records = records;
          _inventoryProducts = inventoryProducts;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception:', '').trim()),
            backgroundColor: const Color(0xFFBA1A1A),
          ),
        );
      }
    }
  }

  void _onStoreChanged(String? newStoreId) {
    if (newStoreId == null || newStoreId == _selectedStoreId) return;
    setState(() {
      _selectedStoreId = newStoreId;
    });
    _reloadRecordsOnly();
  }

  /// Stores accessible by current user (Admin sees all; Storekeeper/Sales sees assigned)
  List<Store> get _accessibleStores {
    if (widget.currentUser.isAdmin) return _stores;
    final list = _stores.where((s) => widget.currentUser.canAccessStore(s.id)).toList();
    return list.isNotEmpty ? list : _stores;
  }

  List<LedgerRecord> get _filteredRecords {
    final type = _currentTabType;
    final list = _records.where((r) {
      if (widget.currentUser.isStorekeeper || widget.currentUser.isSales) {
        if (r.type != 'stock') return false;
        if (_selectedStoreId != null &&
            _selectedStoreId!.isNotEmpty &&
            _selectedStoreId != 'all') {
          if (r.storeId != null && r.storeId != _selectedStoreId) return false;
        }
      } else {
        if (r.type != type) return false;
        // Store filter ONLY applies on the Store tab (_currentTabIndex == 3)
        // On Customer, Supplier, and Delala screens, store filter does not hide records
        if (_currentTabIndex == 3) {
          if (_selectedStoreId != null &&
              _selectedStoreId != 'all' &&
              r.storeId != null &&
              r.storeId != _selectedStoreId) {
            return false;
          }
        }
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = r.title.toLowerCase().contains(q);
        final matchNotes = r.notes?.toLowerCase().contains(q) ?? false;
        final matchItems = r.items.any(
          (it) => it.name.toLowerCase().contains(q),
        );
        if (!matchTitle && !matchNotes && !matchItems) return false;
      }
      return true;
    }).toList();

    // Fix duplicate same names: Consolidate records by title and type into one card
    final Map<String, LedgerRecord> merged = {};
    for (final r in list) {
      final key = '${r.type}-${r.title.trim().toLowerCase()}';
      if (!merged.containsKey(key)) {
        merged[key] = r;
      } else {
        final exist = merged[key]!;
        final Set<String> existingItemIds = exist.items.map((it) => it.id).toSet();
        final newItems = r.items.where((it) => !existingItemIds.contains(it.id)).toList();
        final combinedItems = [...exist.items, ...newItems];
        final latestDate = r.date.compareTo(exist.date) > 0 ? r.date : exist.date;
        final latestCreated = (r.createdAt ?? 0) > (exist.createdAt ?? 0)
            ? r.createdAt
            : exist.createdAt;
        final latestUpdated = (r.updatedAt ?? 0) > (exist.updatedAt ?? 0)
            ? r.updatedAt
            : exist.updatedAt;

        merged[key] = exist.copyWith(
          items: combinedItems,
          date: latestDate,
          notes: (r.notes != null && r.notes!.isNotEmpty)
              ? (exist.notes != null && exist.notes!.isNotEmpty
                  ? '${exist.notes}; ${r.notes}'
                  : r.notes)
              : exist.notes,
          createdAt: latestCreated,
          updatedAt: latestUpdated,
        );
      }
    }

    final result = merged.values.toList();

    // Newly registered and updated records at the TOP of the list!
    result.sort((a, b) {
      final aTime = (a.updatedAt != null && a.updatedAt! > 0)
          ? a.updatedAt!
          : (a.createdAt ?? 0);
      final bTime = (b.updatedAt != null && b.updatedAt! > 0)
          ? b.updatedAt!
          : (b.createdAt ?? 0);
      return bTime.compareTo(aTime);
    });

    return result;
  }

  Future<void> _openCreateRecordDialog() async {
    final result = await showDialog<LedgerRecord>(
      context: context,
      builder: (ctx) => RecordFormDialog(
        activeTab: _currentTabType,
        existingRecords: _records,
        storeId: (widget.currentUser.isStorekeeper ||
                widget.currentUser.isSales)
            ? widget.currentUser.storeId
            : (_selectedStoreId == 'all'
                  ? (_stores.isNotEmpty ? _stores.first.id : null)
                  : _selectedStoreId),
      ),
    );

    if (result != null) {
      try {
        // Smart merge: if party/stock ledger already exists in this store, append new transaction rows (Fix duplicate same names)
        final existingIdx = _records.indexWhere(
          (r) =>
              r.type == result.type &&
              r.title.trim().toLowerCase() ==
                  result.title.trim().toLowerCase() &&
              (r.storeId == result.storeId ||
                  r.storeId == null ||
                  result.storeId == null),
        );

        if (existingIdx >= 0) {
          final existing = _records[existingIdx];
          final updated = existing.copyWith(
            items: [...existing.items, ...result.items],
            notes: (result.notes != null && result.notes!.isNotEmpty)
                ? result.notes
                : existing.notes,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
          await ApiService.updateRecord(updated);
          setState(() {
            _records.removeAt(existingIdx);
            _records.insert(0, updated);
          });
          _reloadRecordsOnly();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isAmharic
                    ? '"${existing.title}" ላይ ዝርዝሩ ተጨምሮ ተመዝግቧል'
                    : 'Added transaction to "${existing.title}"',
              ),
              backgroundColor: const Color(0xFF2563EB),
            ),
          );
        } else {
          final created = await ApiService.createRecord(result, storeId: result.storeId);
          setState(() {
            _records.insert(0, created);
          });
          _reloadRecordsOnly();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isAmharic
                    ? '"${result.title}" በተሳካ ሁኔታ ተመዝግቧል'
                    : 'Saved "${result.title}" successfully',
              ),
              backgroundColor: const Color(0xFF2563EB),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception:', ''))),
        );
      }
    }
  }

  Future<void> _openEditRecordDialog(LedgerRecord record) async {
    final result = await showDialog<LedgerRecord>(
      context: context,
      builder: (ctx) => RecordFormDialog(
        activeTab: record.type,
        editingRecord: record,
        existingRecords: _records,
        storeId: record.storeId,
      ),
    );

    if (result != null) {
      try {
        await ApiService.updateRecord(result);
        _reloadRecordsOnly();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated "${result.title}" in Neon DB'),
            backgroundColor: const Color(0xFF2563EB),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception:', ''))),
        );
      }
    }
  }

  Future<void> _deleteRecord(LedgerRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text('Delete "${record.title}" from ledger?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ApiService.deleteRecord(record.id);
      _reloadRecordsOnly();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Deleted "${record.title}"')));
    }
  }

  void _openStatement(LedgerRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatementScreen(
          accountName: record.title,
          accountType: record.type,
          storeId: record.storeId,
        ),
      ),
    );
  }

  Future<void> _openAddAuditEntry(LedgerRecord record) async {
    final result = await showDialog<LedgerRecord>(
      context: context,
      builder: (ctx) => RecordFormDialog(
        activeTab: record.type,
        existingRecords: _records,
        initialPartyName: record.title,
        storeId:
            record.storeId ??
            (_selectedStoreId == 'all' ? null : _selectedStoreId),
      ),
    );

    if (result != null) {
      try {
        final existingIdx = _records.indexWhere((r) => r.id == record.id);
        if (existingIdx >= 0) {
          final existing = _records[existingIdx];
          final updated = existing.copyWith(
            items: [...existing.items, ...result.items],
            notes: (result.notes != null && result.notes!.isNotEmpty)
                ? result.notes
                : existing.notes,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
          await ApiService.updateRecord(updated);
          _reloadRecordsOnly();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isAmharic
                    ? '"${record.title}" ላይ ማወራረጃ ተመዝግቧል'
                    : 'Audit entry added for "${record.title}"',
              ),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        } else {
          await ApiService.createRecord(result, storeId: result.storeId);
          _reloadRecordsOnly();
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception:', ''))),
        );
      }
    }
  }

  void _showRecordActions(LedgerRecord record) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                              height: 1.25,
                            ),
                            softWrap: true,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Balance: ETB ${_currencyFormat.format(record.balance)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.fact_check_outlined,
                  color: Color(0xFF16A34A),
                ),
                title: Text(
                  _isAmharic
                      ? 'ማወራረጃ መዝግብ (ዕቃ / ብር)'
                      : 'Add Audit Entry (Items / Money)',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAddAuditEntry(record);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.table_chart_outlined,
                  color: Color(0xFF2563EB),
                ),
                title: const Text('View Full Statement & PDF'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openStatement(record);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                  color: Color(0xFF4059AA),
                ),
                title: const Text('Edit Entry'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openEditRecordDialog(record);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFBA1A1A),
                ),
                title: const Text('Delete Entry'),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteRecord(record);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Widget _buildTopGridCard({
    required bool isDark,
    required String title,
    required String mainValue,
    required String subtitle,
    String? currencyPrefix,
    Color? valueColor,
    EdgeInsetsGeometry? padding,
  }) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (currencyPrefix != null) ...[
                  Text(
                    currencyPrefix,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: valueColor != null
                          ? valueColor.withValues(alpha: 0.8)
                          : subColor,
                    ),
                  ),
                  const SizedBox(width: 2.5),
                ],
                Text(
                  mainValue,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    letterSpacing: -0.3,
                    color: valueColor ?? textColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: subColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Classified Statement Summary Grid Cards (Customer, Supplier, Delala, and Store)
  Widget _buildStatementSummary(ThemeData theme, bool isDark) {
    Widget card1;
    Widget card2;
    Widget card3;

    if (_currentTabType == 'customer') {
      final records = _filteredRecords;
      double totalDebit = 0;
      double totalCredit = 0;
      for (final r in records) {
        totalDebit += r.totalDebit;
        totalCredit += r.totalCredit;
      }
      final netBalance = totalDebit - totalCredit;

      // Card 1: Invoiced (Debit -> Amber / Yellow distinct from Balance Red)
      card1 = _buildTopGridCard(
        isDark: isDark,
        title: _isAmharic ? 'ኢንቮይስ' : 'Invoiced',
        mainValue: _currencyFormat.format(totalDebit),
        currencyPrefix: _isAmharic ? 'ብር' : 'ETB',
        subtitle: _isAmharic ? 'ዴቢት' : 'Debit',
        valueColor: const Color(0xFFD97706),
      );

      // Card 2: Received (Income -> Green)
      card2 = _buildTopGridCard(
        isDark: isDark,
        title: _isAmharic ? 'የተከፈለ' : 'Received',
        mainValue: _currencyFormat.format(totalCredit),
        currencyPrefix: _isAmharic ? 'ብር' : 'ETB',
        subtitle: _isAmharic ? 'ክሬዲት' : 'Credit',
        valueColor: const Color(0xFF16A34A),
      );

      // Card 3: Balance
      final isReceivable = netBalance > 0;
      final isOverpaid = netBalance < 0;
      card3 = _buildTopGridCard(
        isDark: isDark,
        title: _isAmharic ? 'ቀሪ' : 'Balance',
        mainValue: _currencyFormat.format(netBalance.abs()),
        currencyPrefix: _isAmharic ? 'ብር' : 'ETB',
        subtitle: isReceivable
            ? (_isAmharic ? 'ተሰብሳቢ' : 'Receivable')
            : (isOverpaid
                  ? (_isAmharic ? 'ትርፍ' : 'Overpaid')
                  : (_isAmharic ? 'ተወራርዷል' : 'Settled')),
        valueColor: isReceivable
            ? const Color(0xFFDC2626)
            : const Color(0xFF16A34A),
      );
    } else if (_currentTabType == 'supplier') {
      final records = _filteredRecords;
      double totalDebit = 0;
      double totalCredit = 0;
      for (final r in records) {
        totalDebit += r.totalDebit;
        totalCredit += r.totalCredit;
      }
      final netBalance = totalDebit - totalCredit;

      // Card 1: Invoiced (Debit -> Amber / Yellow distinct from Balance Red)
      card1 = _buildTopGridCard(
        isDark: isDark,
        title: _isAmharic ? 'ኢንቮይስ' : 'Invoiced',
        mainValue: _currencyFormat.format(totalDebit),
        currencyPrefix: _isAmharic ? 'ብር' : 'ETB',
        subtitle: _isAmharic ? 'ዴቢት' : 'Debit',
        valueColor: const Color(0xFFD97706),
      );

      // Card 2: Received (Income -> Green)
      card2 = _buildTopGridCard(
        isDark: isDark,
        title: _isAmharic ? 'የተከፈለ' : 'Received',
        mainValue: _currencyFormat.format(totalCredit),
        currencyPrefix: _isAmharic ? 'ብር' : 'ETB',
        subtitle: _isAmharic ? 'ክሬዲት' : 'Credit',
        valueColor: const Color(0xFF16A34A),
      );

      // Card 3: Balance
      final isPayable = netBalance > 0;
      final isAdvance = netBalance < 0;
      card3 = _buildTopGridCard(
        isDark: isDark,
        title: _isAmharic ? 'ቀሪ' : 'Balance',
        mainValue: _currencyFormat.format(netBalance.abs()),
        currencyPrefix: _isAmharic ? 'ብር' : 'ETB',
        subtitle: isPayable
            ? (_isAmharic ? 'ተከፋይ' : 'Payable')
            : (isAdvance
                  ? (_isAmharic ? 'ቅድመ' : 'Advance')
                  : (_isAmharic ? 'ተወራርዷል' : 'Settled')),
        valueColor: isPayable
            ? const Color(0xFFDC2626)
            : const Color(0xFF16A34A),
      );
    } else if (_currentTabType == 'delala') {
      final records = _filteredRecords;
      double totalBorrowedPrice = 0;
      double totalSettledPrice = 0;
      for (final r in records) {
        for (final it in r.items) {
          if (it.sign == '+') {
            totalBorrowedPrice += it.subtotal;
          } else {
            final isItemReturn =
                it.packagingUnit != 'Payment' &&
                (it.customType == 'Item Return' ||
                    (it.quantity > 0 &&
                        it.name.trim().toLowerCase() != 'payment'));
            if (isItemReturn) {
              totalSettledPrice += it.subtotal;
            } else {
              totalSettledPrice += it.subtotal;
            }
          }
        }
      }
      final netBalance = totalBorrowedPrice - totalSettledPrice;

      // Card 1: Invoiced (Borrowed goods / Debit -> Amber / Yellow #D97706)
      card1 = _buildTopGridCard(
        isDark: isDark,
        title: _isAmharic ? 'ኢንቮይስ' : 'Invoiced',
        mainValue: _currencyFormat.format(totalBorrowedPrice),
        currencyPrefix: _isAmharic ? 'ብር' : 'ETB',
        subtitle: _isAmharic ? 'ዴቢት' : 'Debit',
        valueColor: const Color(0xFFD97706),
      );

      // Card 2: Received (Settled / Payments / Income -> Green)
      card2 = _buildTopGridCard(
        isDark: isDark,
        title: _isAmharic ? 'የተከፈለ' : 'Received',
        mainValue: _currencyFormat.format(totalSettledPrice),
        currencyPrefix: _isAmharic ? 'ብር' : 'ETB',
        subtitle: _isAmharic ? 'ክሬዲት' : 'Credit',
        valueColor: const Color(0xFF16A34A),
      );

      // Card 3: Balance
      final isReceivable = netBalance > 0;
      final isPayable = netBalance < 0;
      card3 = _buildTopGridCard(
        isDark: isDark,
        title: _isAmharic ? 'ቀሪ' : 'Balance',
        mainValue: _currencyFormat.format(netBalance.abs()),
        currencyPrefix: _isAmharic ? 'ብር' : 'ETB',
        subtitle: isReceivable
            ? (_isAmharic ? 'ተሰብሳቢ' : 'Receivable')
            : (isPayable
                  ? (_isAmharic ? 'ተከፋይ' : 'Payable')
                  : (_isAmharic ? 'ተወራርዷል' : 'Settled')),
        valueColor: isReceivable
            ? const Color(0xFFDC2626)
            : const Color(0xFF16A34A),
      );
    } else {
      // Store / Stock
      double totalStoreValue = 0;
      double totalPieces = 0;
      for (final prod in _inventoryProducts) {
        final pcs = prod.currentQuantity;
        totalPieces += pcs;
        totalStoreValue += (prod.totalValue > 0
            ? prod.totalValue
            : pcs * prod.costPrice);
      }

      final compactPad = widget.currentUser.isAdmin
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 7)
          : null;

      // Card 1: Valuation
      card1 = _buildTopGridCard(
        isDark: isDark,
        title: _isAmharic ? 'ዋጋ' : 'Valuation',
        mainValue: widget.currentUser.isAdmin
            ? _currencyFormat.format(totalStoreValue)
            : '•••',
        currencyPrefix: widget.currentUser.isAdmin
            ? (_isAmharic ? 'ብር' : 'ETB')
            : null,
        subtitle: widget.currentUser.isAdmin
            ? (_isAmharic ? 'ጠቅላላ' : 'Total')
            : (_isAmharic ? 'አድሚን' : 'Admin'),
        valueColor:
            widget.currentUser.isAdmin ? const Color(0xFFD97706) : null,
        padding: compactPad,
      );

      // Card 2: Products
      card2 = _buildTopGridCard(
        isDark: isDark,
        title: _isAmharic ? 'ምርቶች' : 'Products',
        mainValue:
            '${_inventoryProducts.length} ${_isAmharic ? "ዓይነት" : "Items"}',
        subtitle: _isAmharic ? 'ካታሎግ' : 'Catalog',
        valueColor: const Color(0xFF2563EB),
        padding: compactPad,
      );

      // Card 3: Stock
      card3 = _buildTopGridCard(
        isDark: isDark,
        title: _isAmharic ? 'ክምችት' : 'Stock',
        mainValue: '${totalPieces.toInt()} ${_isAmharic ? "ፍሬ" : "pcs"}',
        subtitle: _isAmharic ? 'ያለ' : 'Available',
        valueColor: const Color(0xFF16A34A),
        padding: compactPad,
      );

      if (widget.currentUser.isAdmin) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          child: Row(
            children: [
              Expanded(child: card1),
              const SizedBox(width: 8),
              Expanded(child: card2),
              const SizedBox(width: 8),
              Expanded(child: card3),
            ],
          ),
        );
      }
    }

    if (_currentTabType == 'stock' && !widget.currentUser.isAdmin) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        child: Row(
          children: [
            Expanded(child: card2),
            const SizedBox(width: 8),
            Expanded(child: card3),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Row(
        children: [
          Expanded(child: card1),
          const SizedBox(width: 8),
          Expanded(child: card2),
          const SizedBox(width: 8),
          Expanded(child: card3),
        ],
      ),
    );
  }

  /* ------------------- Advanced Store Inventory Methods ------------------- */

  Future<void> _openNewProductDialog() async {
    final result = await showDialog<InventoryProduct>(
      context: context,
      builder: (ctx) => NewProductDialog(
        currentUser: widget.currentUser,
        activeStoreId: _selectedStoreId,
        isAmharic: _isAmharic,
      ),
    );

    if (result != null && mounted) {
      // Place newly registered product at the top of the list & auto-expand (new register do top list)
      setState(() {
        _inventoryProducts.removeWhere((p) =>
            p.id == result.id ||
            p.productName.trim().toLowerCase() ==
                result.productName.trim().toLowerCase());
        _inventoryProducts.insert(0, result);
        _expandedProductIds.add(result.id);
      });
      await _reloadRecordsOnly();
      if (!mounted) return;
      setState(() {
        _expandedProductIds.add(result.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isAmharic
                ? '"${result.productName}" በተሳካ ሁኔታ ተመዝግቧል'
                : 'Product "${result.productName}" registered successfully',
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    }
  }

  Future<void> _openStockTransactionDialog([
    InventoryProduct? preselected,
    String initialType = 'IN',
  ]) async {
    final result = await showDialog<InventoryProduct>(
      context: context,
      builder: (ctx) => StockTransactionDialog(
        currentUser: widget.currentUser,
        activeStoreId: _selectedStoreId,
        availableProducts: _inventoryProducts,
        preselectedProduct: preselected,
        initialMovementType: initialType,
        isAmharic: _isAmharic,
      ),
    );

    if (result != null && mounted) {
      // Move updated product to the top of the list & keep expanded
      setState(() {
        _inventoryProducts.removeWhere((p) =>
            p.id == result.id ||
            p.productName.trim().toLowerCase() ==
                result.productName.trim().toLowerCase());
        _inventoryProducts.insert(0, result);
        _expandedProductIds.add(result.id);
      });
      await _reloadRecordsOnly();
      if (!mounted) return;
      setState(() {
        _expandedProductIds.add(result.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isAmharic
                ? 'የክምችት ዝውውር በተሳካ ሁኔታ ተመዝግቧል'
                : 'Stock movement recorded successfully',
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    }
  }

  Future<void> _openProductHistoryDialog(InventoryProduct prod) async {
    await showDialog(
      context: context,
      builder: (ctx) =>
          ProductHistoryDialog(product: prod, isAmharic: _isAmharic),
    );
  }

  Future<void> _openEditProductDialog(InventoryProduct prod) async {
    final result = await showDialog<InventoryProduct>(
      context: context,
      builder: (ctx) => EditProductDialog(
        product: prod,
        currentUser: widget.currentUser,
        isAmharic: _isAmharic,
      ),
    );

    if (result != null && mounted) {
      await _reloadRecordsOnly();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isAmharic ? 'የዕቃ መረጃ ተስተካክሏል' : 'Product updated successfully',
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    }
  }

  void _openSettingsModal() {
    final titleController = TextEditingController(
      text: AppSettingsService.appTitleNotifier.value,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final cardColor = isDark ? const Color(0xFF1B2234) : Colors.white;
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isAmharic ? 'ቅንብሮች' : 'Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Language Switch Row
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF242C40)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2E384D)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isAmharic ? 'ቋንቋ' : 'Language',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  await LanguageService.setLanguage('en');
                                  if (mounted) setState(() {});
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: !_isAmharic
                                        ? const Color(0xFF2563EB)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: !_isAmharic
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'English',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: !_isAmharic
                                          ? Colors.white
                                          : (isDark
                                                ? Colors.white70
                                                : const Color(0xFF334155)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  await LanguageService.setLanguage('am');
                                  if (mounted) setState(() {});
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _isAmharic
                                        ? const Color(0xFF2563EB)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _isAmharic
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'አማርኛ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _isAmharic
                                          ? Colors.white
                                          : (isDark
                                                ? Colors.white70
                                                : const Color(0xFF334155)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Business Branding & Logo Settings (Dynamic App Title and Logo)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF242C40)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2E384D)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: StatefulBuilder(
                      builder: (ctx2, setLocalState) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isAmharic
                                  ? 'የንግድ ስም እና ሎጎ (Branding)'
                                  : 'Business Branding & Logo',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                AppSettingsService.buildLogoWidget(size: 40),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _isAmharic
                                        ? 'የመረጡት ሎጎ በራስጌ እና በፒዲኤፍ ሪፖርቶች ላይ ይታያል'
                                        : 'Your logo appears in app headers and PDF statements',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    try {
                                      final success =
                                          await AppSettingsService.pickAndSaveLogo();
                                      if (success) {
                                        setLocalState(() {});
                                        if (mounted) setState(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              _isAmharic
                                                  ? 'የሎጎ ምስል በተሳካ ሁኔታ ተጭኗል!'
                                                  : 'Logo image uploaded successfully!',
                                            ),
                                            backgroundColor: const Color(
                                              0xFF16A34A,
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Logo upload error: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.add_photo_alternate_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    _isAmharic ? 'የሎጎ ምስል ጫን' : 'Upload Logo',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                if (AppSettingsService.hasCustomLogo) ...[
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await AppSettingsService.resetToDefaultLogo();
                                      setLocalState(() {});
                                      if (mounted) setState(() {});
                                    },
                                    icon: const Icon(
                                      Icons.restore_rounded,
                                      size: 15,
                                    ),
                                    label: Text(
                                      _isAmharic ? 'ነባሪ ሎጎ' : 'Reset Logo',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: titleController,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              decoration: InputDecoration(
                                labelText: _isAmharic
                                    ? 'የመተግበሪያ / የንግድ ስም'
                                    : 'App / Business Title',
                                labelStyle: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                isDense: true,
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2563EB),
                                    width: 1.5,
                                  ),
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.check_circle, size: 20, color: Color(0xFF16A34A)),
                                  tooltip: _isAmharic ? 'አስቀምጥ' : 'Save Title',
                                  onPressed: () async {
                                    await AppSettingsService.setAppTitle(
                                      titleController.text,
                                    );
                                    setLocalState(() {});
                                    if (mounted) setState(() {});
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            _isAmharic
                                                ? 'የንግድ ስም በተሳካ ሁኔታ ተቀምጧል!'
                                                : 'Business title saved successfully!',
                                          ),
                                          backgroundColor: const Color(0xFF16A34A),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                              onSubmitted: (val) async {
                                await AppSettingsService.setAppTitle(val);
                                setLocalState(() {});
                                if (mounted) setState(() {});
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _isAmharic
                                            ? 'የንግድ ስም በተሳካ ሁኔታ ተቀምጧል!'
                                            : 'Business title saved successfully!',
                                      ),
                                      backgroundColor: const Color(0xFF16A34A),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (widget.currentUser.isAdmin) ...[
                    const SizedBox(height: 12),
                    // Salespersons & Storekeepers Management (Add Sales & Manage All in Settings)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF242C40)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2E384D)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.admin_panel_settings_rounded,
                                size: 19,
                                color: Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isAmharic
                                    ? 'የሽያጭ ሠራተኞች እና መደብሮች አስተዳድር'
                                    : 'Sales, Storekeepers & Stores',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isAmharic
                                ? 'የሽያጭ ሠራተኞችን (Sales) መዝግብ ወይም ሁሉንም መደብሮች እና ተጠቃሚዎች በአንድ ቦታ አስተዳድር፦'
                                : 'Add Sales account or open Manage All to organize stores and accounts:',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _openAddSalesUserDialog();
                                  },
                                  icon: const Icon(
                                    Icons.person_add_alt_1_outlined,
                                    size: 15,
                                  ),
                                  label: Text(
                                    _isAmharic ? '+ ሽያጭ መዝግብ' : '+ Add Sales',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const AdminUsersScreen(),
                                      ),
                                    );
                                    _loadStoresAndRecords();
                                  },
                                  icon: const Icon(Icons.manage_accounts_rounded, size: 16),
                                  label: Text(
                                    _isAmharic ? 'ሁሉንም አስተዳድር' : 'Manage All',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                                    side: BorderSide(
                                      color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAddSalesUserDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String? selectedStore = _stores.isNotEmpty ? _stores.first.id : null;
    bool isSaving = false;
    String? errorMsg;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.point_of_sale_rounded,
                  color: Color(0xFF16A34A),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  _isAmharic
                      ? 'አዲስ የሽያጭ ሠራተኛ (Sales)'
                      : 'Add New Salesperson',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (errorMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        errorMsg!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: _isAmharic ? 'ሙሉ ስም *' : 'Full Name *',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: _isAmharic
                          ? 'ስልክ ቁጥር (መግቢያ) *'
                          : 'Phone Number (Login) *',
                      hintText: '0911111111',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: _isAmharic ? 'የይለፍ ቃል *' : 'Password *',
                      hintText: _isAmharic
                          ? 'ቢያንስ 6 ፊደላት'
                          : 'At least 6 characters',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStore,
                    decoration: InputDecoration(
                      labelText: _isAmharic
                          ? 'የሚሠራበት መደብር *'
                          : 'Assigned Store *',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final s in _stores)
                        DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (val) {
                      setDlgState(() => selectedStore = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(_isAmharic ? 'ሰርዝ' : 'Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        final phone = phoneCtrl.text.trim();
                        final pass = passCtrl.text;
                        if (name.isEmpty || phone.isEmpty || pass.length < 6) {
                          setDlgState(
                            () => errorMsg = _isAmharic
                                ? 'እባክዎ ስም፣ ስልክ እና ቢያንስ 6 ፊደል የይለፍ ቃል ያስገቡ'
                                : 'Enter name, phone and at least 6 characters password',
                          );
                          return;
                        }
                        if (selectedStore == null) {
                          setDlgState(
                            () => errorMsg = _isAmharic
                                ? 'መደብር ይምረጡ'
                                : 'Select a store',
                          );
                          return;
                        }
                        setDlgState(() {
                          isSaving = true;
                          errorMsg = null;
                        });
                        try {
                          await ApiService.createUser(
                            name: name,
                            phone: phone,
                            password: pass,
                            storeId: selectedStore!,
                            role: 'sales',
                          );
                          if (!mounted) return;
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _isAmharic
                                    ? 'የሽያጭ ሠራተኛ "$name" በተሳካ ሁኔታ ተመዝግቧል!'
                                    : 'Salesperson "$name" created successfully!',
                              ),
                              backgroundColor: const Color(0xFF16A34A),
                            ),
                          );
                          _loadStoresAndRecords();
                        } catch (e) {
                          setDlgState(() {
                            isSaving = false;
                            errorMsg = e
                                .toString()
                                .replaceAll('Exception:', '')
                                .trim();
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(_isAmharic ? 'መዝግብ' : 'Create Sales'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Advanced Mobile Store Inventory View (Real Inventory System)
  Widget _buildStockInventorySheet(ThemeData theme, bool isDark) {
    final gridBorderColor = isDark
        ? const Color(0xFF2E384D)
        : const Color(0xFFCBD5E1);

    final query = _searchQuery.trim().toLowerCase();
    final rawFiltered = _inventoryProducts.where((p) {
      if (_selectedStoreId != null &&
          _selectedStoreId != 'all' &&
          p.storeId != null &&
          p.storeId != _selectedStoreId) {
        return false;
      }
      if (query.isEmpty) return true;
      return p.productName.toLowerCase().contains(query) ||
          (p.supplierName?.toLowerCase().contains(query) ?? false) ||
          (p.description?.toLowerCase().contains(query) ?? false) ||
          (p.category.toLowerCase().contains(query));
    }).toList();

    // Fix duplicate same names: Consolidate any duplicate products by name
    final Map<String, InventoryProduct> mergedMap = {};
    for (final p in rawFiltered) {
      final key = p.productName.trim().toLowerCase();
      if (!mergedMap.containsKey(key)) {
        mergedMap[key] = p;
      } else {
        final exist = mergedMap[key]!;
        final combinedQty = exist.currentQuantity + p.currentQuantity;
        final latestPrice = p.unitPrice > 0 ? p.unitPrice : exist.unitPrice;
        final latestSkPrice = p.storekeeperPrice > 0
            ? p.storekeeperPrice
            : exist.storekeeperPrice;
        final effectivePcs = exist.pcsPerCarton > 0
            ? exist.pcsPerCarton
            : (p.pcsPerCarton > 0 ? p.pcsPerCarton : 1.0);
        final combinedCartons = (combinedQty / effectivePcs).floorToDouble();
        final combinedValue = combinedQty * latestPrice;
        final latestCreated = (exist.createdAt != null && p.createdAt != null)
            ? (p.createdAt!.isAfter(exist.createdAt!) ? p.createdAt : exist.createdAt)
            : (exist.createdAt ?? p.createdAt);

        mergedMap[key] = InventoryProduct(
          id: exist.id,
          storeId: exist.storeId ?? p.storeId,
          productName: exist.productName,
          sku: exist.sku,
          category: exist.category,
          baseUnit: exist.baseUnit,
          quantityCartons: combinedCartons,
          quantityPerCarton: effectivePcs,
          totalQuantity: combinedQty,
          unit: exist.unit,
          pricePerPiece: latestPrice,
          totalValue: combinedValue,
          currentQuantity: combinedQty,
          minimumStock:
              exist.minimumStock > 0 ? exist.minimumStock : p.minimumStock,
          unitPrice: latestPrice,
          costPrice: exist.costPrice > 0 ? exist.costPrice : p.costPrice,
          storekeeperPrice: latestSkPrice,
          pcsPerCarton: effectivePcs,
          supplierName: exist.supplierName ?? p.supplierName,
          lastTransactionDate: p.lastTransactionDate ?? exist.lastTransactionDate,
          description: exist.description ?? p.description,
          createdBy: exist.createdBy,
          updatedBy: p.updatedBy ?? exist.updatedBy,
          isDeleted: false,
          isActive: true,
          createdAt: latestCreated,
          updatedAt: DateTime.now(),
        );
      }
    }
    final filteredProducts = mergedMap.values.toList();

    // Newly registered products at the TOP of the list!
    filteredProducts.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;
      if (aDate != null && bDate != null) {
        return bDate.compareTo(aDate);
      }
      if (aDate != null) return -1;
      if (bDate != null) return 1;
      return 0;
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 85),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Store Switcher Dropdown Component (inside Stock tab)
          if (_stores.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Tooltip(
                message: _activeStoreLabel,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                      width: 1,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: (_selectedStoreId == 'all' ||
                            _stores.any((s) => s.id == _selectedStoreId))
                        ? _selectedStoreId
                        : (_stores.isNotEmpty ? _stores.first.id : 'all'),
                    isDense: true,
                    isExpanded: true,
                    dropdownColor:
                        isDark ? const Color(0xFF1E293B) : Colors.white,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      size: 22,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF475569),
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'all',
                        child: Row(
                          children: [
                            const Icon(Icons.storefront_outlined,
                                size: 16, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Text(
                              _isAmharic ? 'ሁሉም መደብሮች' : 'All Stores',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      ..._accessibleStores.map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Row(
                              children: [
                                const Icon(Icons.store_rounded,
                                    size: 16, color: Color(0xFF16A34A)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    s.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        _onStoreChanged(val);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),

          // Store Filter Chips (matching Image 2)
          if (_stores.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(_isAmharic ? 'ሁሉም' : 'All Stores'),
                    selected: _selectedStoreId == 'all' || _selectedStoreId == null,
                    onSelected: (_) => _onStoreChanged('all'),
                    selectedColor: const Color(0xFFDBEAFE),
                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: (_selectedStoreId == 'all' || _selectedStoreId == null)
                          ? const Color(0xFF1D4ED8)
                          : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: (_selectedStoreId == 'all' || _selectedStoreId == null)
                            ? const Color(0xFF93C5FD)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                  for (final s in _accessibleStores) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(s.name),
                      selected: _selectedStoreId == s.id,
                      onSelected: (_) => _onStoreChanged(s.id),
                      selectedColor: const Color(0xFFDBEAFE),
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _selectedStoreId == s.id
                            ? const Color(0xFF1D4ED8)
                            : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: _selectedStoreId == s.id
                              ? const Color(0xFF93C5FD)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // 1. Available Store Items Header Bar (Storekeeper gets "+ Add Item"; Admin is View Mode Only)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF242C40) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: gridBorderColor, width: 1.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isAmharic ? 'በመደብር ውስጥ ያሉ ዕቃዎች' : 'Available Store Items',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isAmharic
                          ? '${filteredProducts.length} ዕቃዎች'
                          : '${filteredProducts.length} Products',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    // Create (+ Add Item) for Storekeeper & Sales
                    if (widget.currentUser.isStorekeeper ||
                        widget.currentUser.isSales) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _openNewProductDialog,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.add,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                _isAmharic ? 'አዲስ ምርት' : 'Add Item',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 3. Products List or Empty State
          if (filteredProducts.isEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B2234) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: gridBorderColor),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 44,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    query.isNotEmpty
                        ? (_isAmharic
                              ? 'የሚዛመድ ዕቃ አልተገኘም'
                              : 'No matching products found')
                        : (_selectedStoreId != 'all'
                              ? (_isAmharic
                                    ? 'በዚህ መደብር ውስጥ ምንም ዳታ የለም (ዳታ ባዶ ነው)'
                                    : 'No data in this store (Data empty)')
                              : (_isAmharic
                                    ? 'በመደብር ውስጥ የተመዘገበ ዕቃ የለም'
                                    : 'No registered products yet')),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  // Register product in empty state is for Storekeeper and Sales
                  if (widget.currentUser.isStorekeeper ||
                      widget.currentUser.isSales) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _openNewProductDialog,
                      icon: const Icon(Icons.add_box_outlined, size: 16),
                      label: Text(
                        _isAmharic
                            ? '+ አዲስ ምርት መዝግብ'
                            : '+ Register New Product',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            Column(
              children: filteredProducts.map((prod) {
                return _buildProductTable(prod, theme, isDark);
              }).toList(),
            ),
        ],
      ),
    );
  }

  /// Product Table card identical to Customer & Supplier table style
  Widget _buildProductTable(
    InventoryProduct prod,
    ThemeData theme,
    bool isDark,
  ) {
    final isExpanded = _expandedProductIds.contains(prod.id);
    final gridBorderColor = isDark
        ? const Color(0xFF2E384D)
        : const Color(0xFFCBD5E1);

    final unitPrice =
        (widget.currentUser.isStorekeeper || widget.currentUser.isSales) &&
                prod.storekeeperPrice > 0
            ? prod.storekeeperPrice
            : (prod.unitPrice > 0 ? prod.unitPrice : prod.costPrice);
    final totalVal = prod.currentQuantity * unitPrice;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2234) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: gridBorderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header (straight level): Chevron + Name & Subtitle | Total Price + Eye Icon + 3-Dot
          InkWell(
            onTap: () => _toggleProductExpanded(prod.id),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF242C40)
                    : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(7),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Expand / Collapse chevron
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),

                  // Product name & category
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          LanguageService.translateProduct(prod.productName),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: theme.colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (prod.isOutOfStock) ...[
                          const SizedBox(height: 1.5),
                          Text(
                            _isAmharic ? 'አልቋል' : 'Out of Stock',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Total Quantity / Items (Replacing price with total items)
                  RichText(
                    textAlign: TextAlign.end,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${prod.currentQuantity.toInt()} ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        TextSpan(
                          text: _isAmharic ? 'ፍሬ' : 'pcs',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Table View matching customer/supplier table format
          if (isExpanded) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161D2E) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: gridBorderColor, width: 1.0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Table Header Row: # | Pcs/Ctn | Total Pcs | Unit Price | Total Value
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        border: Border(
                          bottom: BorderSide(
                            color: gridBorderColor,
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '#',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 16,
                            color: gridBorderColor,
                          ),
                          Expanded(
                            flex: 7,
                            child: Text(
                              _isAmharic ? 'በካርቶን' : 'Pcs/Ctn',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 16,
                            color: gridBorderColor,
                          ),
                          Expanded(
                            flex: 8,
                            child: Text(
                              _isAmharic ? 'ጠቅላላ' : 'Total',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 16,
                            color: gridBorderColor,
                          ),
                          Expanded(
                            flex: 8,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Text(
                                _isAmharic ? 'የአንዱ ዋጋ' : 'Unit Price',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 16,
                            color: gridBorderColor,
                          ),
                          Expanded(
                            flex: 9,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Text(
                                _isAmharic ? 'ድምር ዋጋ' : 'Total Value',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Data Row
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161D2E) : Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: gridBorderColor,
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // #
                          SizedBox(
                            width: 24,
                            child: Text(
                              '1',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 22,
                            color: gridBorderColor,
                          ),

                          // በካርቶን (Yellow / Amber)
                          Expanded(
                            flex: 7,
                            child: Text(
                              '${prod.pcsPerCarton.toInt()}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                color: isDark
                                    ? const Color(0xFFFBBF24)
                                    : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 22,
                            color: gridBorderColor,
                          ),

                          // ጠቅላላ ፍሬ (Green)
                          Expanded(
                            flex: 8,
                            child: Text(
                              NumberFormat('#,##0')
                                  .format(prod.currentQuantity.round()),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 22,
                            color: gridBorderColor,
                          ),

                          // የአንዱ ዋጋ (Yellow / Amber)
                          Expanded(
                            flex: 8,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Text(
                                _currencyFormat.format(unitPrice),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                  color: isDark
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 22,
                            color: gridBorderColor,
                          ),

                          // ድምር ዋጋ (Red)
                          Expanded(
                            flex: 9,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Text(
                                _currencyFormat.format(totalVal),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'monospace',
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Total Footer Row (ጠቅላላ ድምር)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isAmharic
                                ? 'ጠቅላላ ድምር ዋጋ'
                                : 'Total Inventory Value',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: _isAmharic ? 'ብር ' : 'ETB ',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                                TextSpan(
                                  text: _currencyFormat.format(totalVal),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                    color: Color(0xFFDC2626),
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
              ),
            ),

            // Card Footer: Action buttons (Storekeeper and Sales)
            if (widget.currentUser.isStorekeeper || widget.currentUser.isSales)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF242C40)
                      : const Color(0xFFE2E8F0),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(7),
                  ),
                  border: Border(
                    top: BorderSide(color: gridBorderColor, width: 1.2),
                  ),
                ),
                child: Row(
                  children: [
                    // Edit Product button (Storekeeper only)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openEditProductDialog(prod),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                          side: BorderSide(color: gridBorderColor),
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: Text(
                          _isAmharic ? 'አስተካክል' : 'Edit',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Stock In/Out button (Storekeeper only)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openStockTransactionDialog(prod),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                          side: BorderSide(color: gridBorderColor),
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        icon: const Icon(Icons.swap_horiz, size: 14),
                        label: Text(
                          _isAmharic ? 'ገቢ / ወጪ' : 'Add / Out',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // History button (Storekeeper only)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openProductHistoryDialog(prod),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                          side: BorderSide(color: gridBorderColor),
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        icon: const Icon(Icons.history, size: 14),
                        label: Text(
                          _isAmharic ? 'ታሪክ' : 'History',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Authentic Excel Spreadsheet Table View matching the User's Excel Ledger
  Widget _buildRecordTable(LedgerRecord rec, ThemeData theme, bool isDark) {
    final isExpanded = _expandedRecordIds.contains(rec.id);

    // Grid border color for card separators
    final gridBorderColor = isDark
        ? const Color(0xFF2E384D)
        : const Color(0xFFCBD5E1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2234) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: gridBorderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header (mobile friendly): chevron + type badge + name + date | Net Balance + actions
          InkWell(
            onTap: () => _toggleRecordExpanded(rec.id),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF242C40)
                    : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(7),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Expand / Collapse chevron
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),

                  // Name and date / notes (no type badge)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _openStatement(rec),
                          child: Text(
                            rec.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if ((rec.notes != null && rec.notes!.isNotEmpty) ||
                            rec.date.isNotEmpty) ...[
                          const SizedBox(height: 1.5),
                          Builder(
                            builder: (context) {
                              final ethDate = EthiopianCalendar.formatAnyDate(
                                rec.date,
                                lang: _isAmharic ? 'am' : 'en',
                              );
                              return Text(
                                rec.notes != null && rec.notes!.isNotEmpty
                                    ? '$ethDate · ${rec.notes}'
                                    : ethDate,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Price side with pcs underneath (Image 2) and red/green text colors
                  Builder(
                    builder: (context) {
                      final totalRecordPcs = rec.items.fold<double>(0.0, (
                        sum,
                        item,
                      ) {
                        double pcs = 0;
                        if (item.cartons != null &&
                            item.cartons! > 0 &&
                            item.pcsPerCarton != null &&
                            item.pcsPerCarton! > 0) {
                          pcs = item.cartons! * item.pcsPerCarton!;
                        } else if (item.packagingUnit != 'Payment' &&
                            item.quantity > 0) {
                          pcs = item.quantity;
                        }
                        if (item.sign == '+') {
                          return sum + pcs;
                        } else {
                          final isItemReturn =
                              item.packagingUnit != 'Payment' &&
                              (item.customType == 'Item Return' ||
                                  item.customType == 'Return' ||
                                  (item.bank == null &&
                                      item.quantity > 0 &&
                                      !item.name.toLowerCase().startsWith(
                                        'payment',
                                      )));
                          if (isItemReturn) {
                            return sum - pcs;
                          }
                          return sum;
                        }
                      });

                      final balanceColor = rec.balance > 0
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF16A34A);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RichText(
                            textAlign: TextAlign.end,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: _isAmharic ? 'ብር ' : 'ETB ',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: balanceColor,
                                  ),
                                ),
                                TextSpan(
                                  text: _currencyFormat.format(rec.balance),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                    color: balanceColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${totalRecordPcs.abs().toInt()} ${_isAmharic ? "ፍሬ" : "pcs"}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // Eye icon (on straight level)
                  if (rec.type == 'customer' ||
                      rec.type == 'supplier' ||
                      rec.type == 'delala') ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: rec.type == 'delala'
                            ? (isDark ? Colors.white70 : Colors.black87)
                            : const Color(0xFF2563EB),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 26,
                        minHeight: 26,
                      ),
                      splashRadius: 16,
                      tooltip: _isAmharic
                          ? 'ዝርዝር እይ'
                          : 'View Statement Details',
                      onPressed: () => _openStatement(rec),
                    ),
                  ],

                  // 3-dot menu icon (on straight level)
                  const SizedBox(width: 2),
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 26,
                      minHeight: 26,
                    ),
                    splashRadius: 16,
                    tooltip: _isAmharic ? 'ተጨማሪ' : 'Actions',
                    onPressed: () => _showRecordActions(rec),
                  ),
                ],
              ),
            ),
          ),

          // Expanded body: Authentic Table View matching Image 5
          if (isExpanded) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161D2E) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: gridBorderColor, width: 1.0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Table Header Row matching Image 5
                    // # | የዕቃው አይነት | ዋጋ | ብዛት | ድምር
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        border: Border(
                          bottom: BorderSide(
                            color: gridBorderColor,
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '#',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 16,
                            color: gridBorderColor,
                          ),
                          Expanded(
                            flex: 12,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                'የዕቃው አይነት',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 16,
                            color: gridBorderColor,
                          ),
                          Expanded(
                            flex: 7,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Text(
                                'ዋጋ',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 16,
                            color: gridBorderColor,
                          ),
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Text(
                                'ብዛት',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 16,
                            color: gridBorderColor,
                          ),
                          Expanded(
                            flex: 8,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                'ድምር',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Data Rows
                    ...rec.items.asMap().entries.map((entry) {
                      final itemIdx = entry.key + 1;
                      final item = entry.value;
                      final subtotal = item.subtotal;

                      final bank =
                          (item.paymentMethod != null &&
                              item.paymentMethod!.isNotEmpty)
                          ? item.paymentMethod
                          : item.bank;
                      final ctns = item.cartons ?? 0;
                      final pcs = item.pcsPerCarton ?? 0;
                      final unit =
                          item.packagingUnit ?? (ctns > 0 ? 'Carton' : 'Pcs');
                      final isItemReturn =
                          item.sign == '-' &&
                          item.packagingUnit != 'Payment' &&
                          (item.customType == 'Item Return' ||
                              item.customType == 'Return' ||
                              (item.bank == null &&
                                  item.quantity > 0 &&
                                  !item.name.toLowerCase().startsWith(
                                    'payment',
                                  )));
                      final isPayment = item.sign == '-' && !isItemReturn;
                      final packDetail = isPayment
                          ? (bank != null && bank.isNotEmpty
                                ? 'Bank: $bank'
                                : null)
                          : (unit == 'Carton' && ctns > 0 && pcs > 0
                                ? '${ctns.toInt()} ctn × ${pcs.toInt()} pcs'
                                : (ctns > 0
                                      ? '${ctns.toInt()} $unit'
                                      : (item.quantity > 0 && unit != 'Pcs'
                                            ? '${item.quantity.toInt()} $unit'
                                            : null)));

                      final displayName =
                          (rec.type == 'delala' &&
                              isPayment &&
                              (item.name.toLowerCase().contains('payment') ||
                                  item.name.isEmpty))
                          ? (_isAmharic ? 'ደላላ የከፈለው ብር' : 'Delala Cash Payment')
                          : (rec.type == 'delala' &&
                                item.sign == '+' &&
                                bank != null &&
                                bank.isNotEmpty &&
                                (item.name.toLowerCase().contains('payment') ||
                                    item.name.toLowerCase().contains('cash') ||
                                    item.name.isEmpty))
                          ? (_isAmharic ? 'ደላላ የወሰደው ብር' : 'Delala Cash Taken')
                          : item.name;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 7,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (itemIdx % 2 == 0)
                              ? (isDark
                                    ? const Color(0xFF1E2638)
                                    : const Color(0xFFFAFAFA))
                              : (isDark
                                    ? const Color(0xFF161D2E)
                                    : Colors.white),
                          border: Border(
                            bottom: BorderSide(
                              color: gridBorderColor,
                              width: 0.8,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // #
                            SizedBox(
                              width: 24,
                              child: Text(
                                '$itemIdx',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 28,
                              color: gridBorderColor,
                            ),

                            // የዕቃው አይነት (Item)
                            Expanded(
                              flex: 12,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            displayName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Builder(
                                      builder: (context) {
                                        final subDetails = <String>[];
                                        if (rec.type == 'delala' &&
                                            bank != null &&
                                            bank.isNotEmpty) {
                                          subDetails.add(
                                            _isAmharic
                                                ? 'ባንክ፦ $bank'
                                                : 'Bank: $bank',
                                          );
                                        } else if (packDetail != null &&
                                            packDetail.isNotEmpty) {
                                          subDetails.add(packDetail);
                                        }
                                        if (item.date != null &&
                                            item.date!.isNotEmpty) {
                                          subDetails.add(
                                            EthiopianCalendar.formatAnyDate(
                                              item.date!,
                                              lang: _isAmharic ? 'am' : 'en',
                                            ),
                                          );
                                        }
                                        if (item.notes != null &&
                                            item.notes!.isNotEmpty) {
                                          subDetails.add(item.notes!);
                                        } else if (item.reference != null &&
                                            item.reference!.isNotEmpty) {
                                          subDetails.add(item.reference!);
                                        }
                                        if (subDetails.isEmpty) {
                                          return const SizedBox.shrink();
                                        }

                                        return Text(
                                          subDetails.join(' · '),
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 28,
                              color: gridBorderColor,
                            ),

                            // ዋጋ (Unit Price - Yellow / Amber)
                            Expanded(
                              flex: 7,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  _currencyFormat.format(item.unitPrice),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                    color: isDark
                                        ? const Color(0xFFFBBF24)
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 28,
                              color: gridBorderColor,
                            ),

                            // ብዛት (Qty - Green)
                            Expanded(
                              flex: 5,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  item.sign == '-'
                                      ? (isItemReturn
                                            ? '-${item.quantity.toInt()}'
                                            : '-')
                                      : (rec.type == 'delala'
                                            ? (bank != null &&
                                                      bank.isNotEmpty &&
                                                      ctns == 0
                                                  ? '-'
                                                  : '+${item.quantity.toInt()}')
                                            : '${item.quantity.toInt()}'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 28,
                              color: gridBorderColor,
                            ),

                            // ድምር (Total - Red for goods/debit, Green for return/payment)
                            Expanded(
                              flex: 8,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Text(
                                  item.sign == '-'
                                      ? '-${_currencyFormat.format(subtotal)}'
                                      : (rec.type == 'delala'
                                            ? '+${_currencyFormat.format(subtotal)}'
                                            : _currencyFormat.format(subtotal)),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'monospace',
                                    color: item.sign == '-'
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    // ጠቅላላ ድምር Footer Row (exactly like Image 5)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 9,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ጠቅላላ ድምር',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            rec.balance < 0
                                ? '-${_currencyFormat.format(rec.balance.abs())}'
                                : _currencyFormat.format(rec.balance),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              color: rec.balance > 0
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Subtotal Footer Summary
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF242C40)
                    : const Color(0xFFE2E8F0),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(7),
                ),
                border: Border(
                  top: BorderSide(color: gridBorderColor, width: 1.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        rec.type == 'delala'
                            ? (_isAmharic ? 'ደላላ የወሰደው (+)' : 'Delala Took (+)')
                            : (rec.type == 'supplier'
                                  ? (_isAmharic
                                        ? 'ግዢ (አቅራቢ +)'
                                        : 'Purchase (+)')
                                  : (_isAmharic
                                        ? 'ሽያጭ (ደንበኛ +)'
                                        : 'Sale (+)')),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF334155),
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: _isAmharic ? 'ብር ' : 'ETB ',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFD97706),
                              ),
                            ),
                            TextSpan(
                              text: _currencyFormat.format(rec.totalDebit),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11.5,
                                fontFamily: 'monospace',
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        rec.type == 'delala'
                            ? (_isAmharic
                                  ? 'ደላላ የከፈለው / የመለሰው (-)'
                                  : 'Delala Paid / Returned (-)')
                            : (rec.type == 'supplier'
                                  ? (_isAmharic
                                        ? 'ለአቅራቢ የተከፈለ (-)'
                                        : 'Paid to Supplier (-)')
                                  : (_isAmharic
                                        ? 'ከደንበኛ የተቀበልነው (-)'
                                        : 'Customer Paid (-)')),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF334155),
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: _isAmharic ? 'ብር ' : 'ETB ',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                            TextSpan(
                              text: _currencyFormat.format(rec.totalCredit),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11.5,
                                fontFamily: 'monospace',
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        rec.type == 'delala'
                            ? (_isAmharic ? 'ቀሪ ሂሳብ' : 'Net Balance')
                            : (_isAmharic ? 'ቀሪ ዕዳ' : 'Outstanding Balance'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5,
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: _isAmharic ? 'ብር ' : 'ETB ',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: rec.balance > 0
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF16A34A),
                              ),
                            ),
                            TextSpan(
                              text: _currencyFormat.format(rec.balance),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                fontFamily: 'monospace',
                                color: rec.balance > 0
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUser.isStorekeeper) {
      _currentTabIndex = 3;
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final records = _filteredRecords;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF131B2E)
          : const Color(0xFFF5F9ED),
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF182036)
            : const Color(0xFFFFFFFF),
        elevation: 0.5,
        titleSpacing: 12,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        title: Row(
          children: [
            AppSettingsService.buildLogoWidget(size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<String>(
                    valueListenable: AppSettingsService.appTitleNotifier,
                    builder: (context, title, _) {
                      return Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.2,
                        ),
                      );
                    },
                  ),
                  Text(
                    _currentTabLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Settings icon
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
              size: 20,
            ),
            tooltip: _isAmharic ? 'ቅንብሮች' : 'Settings',
            onPressed: _openSettingsModal,
          ),

          // Sign out / Logout icon
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: Color(0xFFBA1A1A),
              size: 19,
            ),
            tooltip: _isAmharic ? 'ውጣ' : 'Sign Out',
            onPressed: _handleLogout,
          ),
        ],
      ),

      // BOTTOM NAVIGATION TABS (Storekeeper only sees Store - no bottom bar; Admin & Sales see tabs)
      bottomNavigationBar: widget.currentUser.isStorekeeper
          ? null
          : Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? const Color(0xFF2E384D)
                        : const Color(0xFFDAE2FD),
                    width: 1,
                  ),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentTabIndex,
                onTap: (index) {
                  setState(() {
                    _currentTabIndex = index;
                  });
                },
                selectedItemColor: isDark
                    ? const Color(0xFF93C5FD)
                    : const Color(0xFF2563EB),
                unselectedItemColor: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
                type: BottomNavigationBarType.fixed,
                backgroundColor: isDark
                    ? const Color(0xFF182036)
                    : Colors.white,
                elevation: 6,
                items: [
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.people_outline),
                    activeIcon: const Icon(Icons.people),
                    label: _isAmharic ? 'ደንበኛ' : 'Customer',
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.business_outlined),
                    activeIcon: const Icon(Icons.business),
                    label: _isAmharic ? 'አቅራቢ' : 'Supplier',
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.handshake_outlined),
                    activeIcon: const Icon(Icons.handshake),
                    label: _isAmharic ? 'ደላላ' : 'Delala',
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.inventory_2_outlined),
                    activeIcon: const Icon(Icons.inventory_2),
                    label: _isAmharic ? 'መደብር' : 'Store',
                  ),
                ],
              ),
            ),

      body: TelebirrBackground(
        isDark: isDark,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _reloadRecordsOnly,
                child: Column(
                  children: [
                    // Search Bar directly at the top of the screen content
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: _currentTabIndex == 3
                              ? (_isAmharic
                                    ? 'የመደብር ዕቃዎችን በስም ወይም በዝርዝር ፈልግ...'
                                    : 'Search Store Inventory by name, item...')
                              : _currentTabIndex == 2
                              ? (_isAmharic
                                    ? 'በስም ወይም በዕቃ ፈልግ...'
                                    : 'Search by name or product...')
                              : (_isAmharic
                                    ? 'በስም ወይም በማስታወሻ ፈልግ...'
                                    : 'Search $_currentTabLabel by name, item...'),
                          hintStyle: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 16,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 14),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF1B2234)
                              : Colors.white,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isDark
                                  ? const Color(0xFF2E384D)
                                  : const Color(0xFFDAE2FD),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isDark
                                  ? const Color(0xFF2E384D)
                                  : const Color(0xFFDAE2FD),
                            ),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val);
                        },
                      ),
                    ),

                    // Statement Summary Card (for Customer, Supplier, Delala, and Store)
                    _buildStatementSummary(theme, isDark),

                    // Content view: Store Inventory on Hand for Stock; Excel Ledgers for Parties & Delala
                    Expanded(
                      child: _currentTabIndex == 3
                          ? _buildStockInventorySheet(theme, isDark)
                          : (records.isEmpty
                                ? (_errorMessage != null
                                      ? Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(24.0),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.cloud_off_rounded,
                                                  size: 42,
                                                  color: Color(0xFFBA1A1A),
                                                ),
                                                const SizedBox(height: 12),
                                                const Text(
                                                  'Online Connection Required',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  _errorMessage!,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF94A3B8,
                                                          )
                                                        : const Color(
                                                            0xFF64748B,
                                                          ),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                ElevatedButton.icon(
                                                  onPressed:
                                                      _loadStoresAndRecords,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            const Color(
                                                              0xFF2563EB,
                                                            ),
                                                        foregroundColor:
                                                            Colors.white,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.refresh,
                                                    size: 16,
                                                  ),
                                                  label: const Text(
                                                    'Retry Connection',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.table_chart_outlined,
                                                size: 38,
                                                color: Colors.grey.shade400,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                _isAmharic
                                                    ? 'ምንም $_currentTabLabel አልተገኘም'
                                                    : 'No $_currentTabLabel entries found',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                  color: isDark
                                                      ? const Color(0xFF94A3B8)
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _isAmharic
                                                    ? 'አዲስ መዝገብ ለማስገባት "+" ይጫኑ'
                                                    : 'Tap "+" to add a new transaction entry',
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ))
                                : ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 75),
                                    itemCount: records.length,
                                    itemBuilder: (ctx, index) {
                                      return _buildRecordTable(
                                        records[index],
                                        theme,
                                        isDark,
                                      );
                                    },
                                  )),
                    ),
                  ],
                ),
              ),
      ),

      // Floating Add Transaction / Store Entry Button
      floatingActionButton:
          (_currentTabIndex == 3 && widget.currentUser.isAdmin)
          ? null
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                _currentTabIndex == 3
                    ? (_isAmharic ? 'የመደብር መዝገብ' : 'Store Entry')
                    : _currentTabIndex == 2
                    ? (_isAmharic ? 'የደላላ መዝገብ' : 'Delala Entry')
                    : _currentTabIndex == 1
                    ? (_isAmharic ? 'የአቅራቢ መዝገብ' : 'Supplier Entry')
                    : (_isAmharic ? 'የደንበኛ መዝገብ' : 'Customer Entry'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              onPressed: _currentTabIndex == 3
                  ? () => _openStockTransactionDialog()
                  : _openCreateRecordDialog,
            ),
    );
  }
}
