import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../models/store.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../widgets/telebirr_background.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<AppUser> _users = [];
  List<Store> _stores = [];
  bool _isLoading = true;
  String? _error;

  final _storeNameController = TextEditingController();
  final _userNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedStoreId;
  final List<String> _selectedStoreIds = [];
  String _selectedRole = 'sales';
  bool _isCreatingStore = false;
  bool _isCreatingUser = false;
  bool _obscurePassword = true;

  String _searchQuery = '';
  String _filterRole = 'all'; // 'all', 'sales', 'storekeeper', 'active', 'inactive'

  bool get _isAmharic => LanguageService.isAmharic;

  List<AppUser> get _filteredUsers {
    return _users.where((u) {
      if (_filterRole == 'sales' && !u.isSales) return false;
      if (_filterRole == 'storekeeper' && !u.isStorekeeper) return false;
      if (_filterRole == 'active' && !u.active) return false;
      if (_filterRole == 'inactive' && u.active) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = u.name.toLowerCase().contains(q);
        final matchPhone = (u.phone ?? '').toLowerCase().contains(q);
        final matchStore = (u.storeName ?? '').toLowerCase().contains(q);
        if (!matchName && !matchPhone && !matchStore) return false;
      }
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _userNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final users = await ApiService.getStorekeepers();
      final stores = await ApiService.getStores();
      if (mounted) {
        setState(() {
          _users = users;
          _stores = stores;
          if (_selectedStoreId == null ||
              !_stores.any((store) => store.id == _selectedStoreId)) {
            _selectedStoreId = _stores.isNotEmpty ? _stores.first.id : null;
          }
          if (_selectedStoreIds.isEmpty && _stores.isNotEmpty) {
            _selectedStoreIds.add(_stores.first.id);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchUsers() async {
    await _loadData();
  }

  Future<void> _createStore() async {
    final name = _storeNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.t('enterStoreName')),
          backgroundColor: AppTheme.roseDanger,
        ),
      );
      return;
    }

    setState(() => _isCreatingStore = true);
    try {
      final store = await ApiService.createStore(name: name);
      _storeNameController.clear();
      await _loadData();
      if (!mounted) return;
      setState(() => _selectedStoreId = store.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.t('createdStore').replaceAll('{storeName}', store.name)),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '')),
          backgroundColor: AppTheme.roseDanger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreatingStore = false);
    }
  }

  Future<void> _deleteStore(Store store) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        backgroundColor: theme.colorScheme.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.roseDangerLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: AppTheme.roseDanger, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        LanguageService.t('deleteStore'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _isAmharic
                      ? 'የመደብሩን ስም "${store.name}" ማስወገድ እርግጠኛ ነዎት? ከመደብሩ ጋር የተያያዙ ሁሉም እቃዎች እና መዝገቦች እስከመጨረሻው ይወገዳሉ።'
                      : 'Are you sure you want to delete "${store.name}"?\n\nAll inventory and transactions associated with this store will be permanently removed.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(LanguageService.t('cancel')),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.roseDanger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                      ),
                      child: Text(LanguageService.t('deleteStore')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteStore(store.id);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.t('deletedStore').replaceAll('{storeName}', store.name)),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '')),
          backgroundColor: AppTheme.roseDanger,
        ),
      );
    }
  }

  Future<void> _showEditStoreDialog(Store store) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: store.name);
    final codeCtrl = TextEditingController(text: store.code);

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        backgroundColor: theme.colorScheme.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_location_alt_rounded, color: AppTheme.primaryBlue, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          LanguageService.t('editStore').replaceAll('{storeName}', store.name),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: LanguageService.t('storeName'),
                    hintText: 'e.g. Merkato Store',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeCtrl,
                  decoration: InputDecoration(
                    labelText: LanguageService.t('storeCode'),
                    hintText: 'e.g. MERKATO-1',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(LanguageService.t('cancel')),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                      ),
                      onPressed: () async {
                        final newName = nameCtrl.text.trim();
                        if (newName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(LanguageService.t('storeNameEmpty'))),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        try {
                          await ApiService.updateStore(
                            store.id,
                            name: newName,
                            code: codeCtrl.text.trim().isNotEmpty ? codeCtrl.text.trim() : null,
                          );
                          await _loadData();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(LanguageService.t('updatedStore').replaceAll('{storeName}', newName)),
                              backgroundColor: AppTheme.emeraldGreen,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString().replaceAll('Exception:', '')),
                              backgroundColor: AppTheme.roseDanger,
                            ),
                          );
                        }
                      },
                      child: Text(LanguageService.t('saveChanges')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createStorekeeper() async {
    final name = _userNameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || phone.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.t('enterNamePhonePassword')),
          backgroundColor: AppTheme.amberWarning,
        ),
      );
      return;
    }

    if (_stores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.t('createStoreFirst')),
          backgroundColor: AppTheme.amberWarning,
        ),
      );
      return;
    }

    if (_selectedStoreIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isAmharic ? 'እባክዎ ቢያንስ አንድ መደብር ይምረጡ' : 'Please assign at least one store location'),
          backgroundColor: AppTheme.amberWarning,
        ),
      );
      return;
    }

    final primaryStoreId = _selectedStoreIds.first;
    final assignedStores = List<String>.from(_selectedStoreIds);

    setState(() => _isCreatingUser = true);
    try {
      await ApiService.createUser(
        name: name,
        phone: phone,
        password: password,
        storeId: primaryStoreId,
        role: _selectedRole,
        assignedStores: assignedStores,
      );
      TextInput.finishAutofillContext(shouldSave: true);
      _userNameController.clear();
      _phoneController.clear();
      _passwordController.clear();
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Created ${_selectedRole == "sales" ? "Sales" : "Storekeeper"} account for $name',
          ),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '')),
          backgroundColor: AppTheme.roseDanger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreatingUser = false);
    }
  }

  Future<void> _deleteStorekeeper(AppUser user) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        backgroundColor: theme.colorScheme.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.roseDangerLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: const Icon(Icons.person_remove_rounded, color: AppTheme.roseDanger, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        LanguageService.t('deleteAccount'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  LanguageService.t('deleteAccountConfirm').replaceAll('{name}', user.name),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(LanguageService.t('cancel')),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.roseDanger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                      ),
                      child: Text(LanguageService.t('delete')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteStorekeeper(user.id);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.t('deletedUser').replaceAll('{name}', user.name)),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '')),
          backgroundColor: AppTheme.roseDanger,
        ),
      );
    }
  }

  Future<void> _showEditUserDialog(AppUser user) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone ?? '');
    final passCtrl = TextEditingController();
    final storeIds = _stores.map((s) => s.id).toSet();
    String selectedStoreId = (user.storeId != null && storeIds.contains(user.storeId))
        ? user.storeId!
        : (_stores.isNotEmpty ? _stores.first.id : '');
    final initialAssigned = user.assignedStoreIds.isNotEmpty
        ? List<String>.from(user.assignedStoreIds)
        : (user.storeId != null && user.storeId!.isNotEmpty ? [user.storeId!] : <String>[]);
    List<String> assignedStores = List<String>.from(initialAssigned);
    String role = user.role;
    bool active = user.active;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
            backgroundColor: theme.colorScheme.surface,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                ),
                                child: const Icon(Icons.manage_accounts_rounded, color: AppTheme.primaryBlue, size: 22),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    LanguageService.t('editUser').replaceAll('{name}', user.name),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    _isAmharic ? 'የተጠቃሚ መረጃ እና ፍቃዶችን ያዘምኑ' : 'Update credentials and store access',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Name Field
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: LanguageService.t('fullName'),
                          prefixIcon: const Icon(Icons.person_outline, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                          filled: true,
                          fillColor: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Phone Field
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: LanguageService.t('phoneNumber'),
                          hintText: 'e.g. 0911111111',
                          prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                          filled: true,
                          fillColor: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Role Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: role,
                        decoration: InputDecoration(
                          labelText: LanguageService.t('accountRole'),
                          prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                          filled: true,
                          fillColor: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'sales',
                            child: Text('Sales (የሽያጭ ሠራተኛ)'),
                          ),
                          DropdownMenuItem(
                            value: 'storekeeper',
                            child: Text('Storekeeper (የመጋዘን ኃላፊ)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDlgState(() => role = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Primary Store Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: selectedStoreId.isEmpty ? null : selectedStoreId,
                        decoration: InputDecoration(
                          labelText: _isAmharic ? 'ዋና መደብር *' : 'Primary Store *',
                          prefixIcon: const Icon(Icons.storefront_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                          filled: true,
                          fillColor: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
                        ),
                        items: [
                          for (final store in _stores)
                            DropdownMenuItem(value: store.id, child: Text(store.name)),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDlgState(() {
                              selectedStoreId = val;
                              if (!assignedStores.contains(val)) {
                                assignedStores.add(val);
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Accessible Stores Chip Wrap
                      Text(
                        _isAmharic ? 'የሚፈቀዱ መደብሮች (Accessible Stores):' : 'Accessible Stores:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final store in _stores)
                            FilterChip(
                              label: Text(store.name, style: const TextStyle(fontSize: 11.5)),
                              selected: assignedStores.contains(store.id),
                              selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.18),
                              checkmarkColor: AppTheme.primaryBlue,
                              onSelected: (selected) {
                                setDlgState(() {
                                  if (selected) {
                                    if (!assignedStores.contains(store.id)) {
                                      assignedStores.add(store.id);
                                    }
                                  } else {
                                    if (assignedStores.length > 1) {
                                      assignedStores.remove(store.id);
                                    }
                                  }
                                  if (!assignedStores.contains(selectedStoreId) &&
                                      assignedStores.isNotEmpty) {
                                    selectedStoreId = assignedStores.first;
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Active Switch
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                            color: active ? AppTheme.emeraldGreen.withValues(alpha: 0.3) : AppTheme.roseDanger.withValues(alpha: 0.3),
                          ),
                        ),
                        child: SwitchListTile(
                          title: Text(
                            LanguageService.t('accountActive'),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            active
                                ? (_isAmharic ? 'መግባት የተፈቀደለት' : 'Allowed to log in')
                                : (_isAmharic ? 'የታገደ አካውንት' : 'Deactivated / blocked'),
                            style: TextStyle(
                              fontSize: 11,
                              color: active ? AppTheme.emeraldGreen : AppTheme.roseDanger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          value: active,
                          activeThumbColor: AppTheme.emeraldGreen,
                          onChanged: (val) {
                            setDlgState(() => active = val);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Password Reset (Optional)
                      TextField(
                        controller: passCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: _isAmharic ? 'የይለፍ ቃል ቀይር (አማራጭ)' : 'Reset Password (optional)',
                          hintText: _isAmharic ? 'ካልተቀየረ ባዶ ይተዉ' : 'Leave empty to keep unchanged',
                          prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                          filled: true,
                          fillColor: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(LanguageService.t('cancel')),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                            ),
                            icon: const Icon(Icons.save_rounded, size: 16),
                            label: Text(LanguageService.t('save')),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              try {
                                await ApiService.updateStorekeeper(
                                  user.id,
                                  name: nameCtrl.text.trim(),
                                  phone: phoneCtrl.text.trim(),
                                  storeId: selectedStoreId.isEmpty ? null : selectedStoreId,
                                  assignedStores: assignedStores,
                                  active: active,
                                  password: passCtrl.text.isNotEmpty ? passCtrl.text : null,
                                  role: role,
                                );
                                _fetchUsers();
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(LanguageService.t('updatedUser').replaceAll('{name}', user.name)),
                                    backgroundColor: AppTheme.emeraldGreen,
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString().replaceAll('Exception:', '')),
                                    backgroundColor: AppTheme.roseDanger,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(LanguageService.t('manageAll')),
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: 0.5,
        foregroundColor: theme.colorScheme.onSurface,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      body: TelebirrBackground(
        isDark: isDark,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 44, color: AppTheme.roseDanger),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: AppTheme.roseDangerDark, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final horizontalPadding = constraints.maxWidth >= 700 ? 24.0 : 12.0;
                      final salesCount = _users.where((u) => u.isSales).length;
                      final storekeeperCount = _users.where((u) => u.isStorekeeper).length;
                      final activeCount = _users.where((u) => u.active).length;
                      final inactiveCount = _users.where((u) => !u.active).length;

                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: ListView(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              12,
                              horizontalPadding,
                              24,
                            ),
                            children: [
                              _buildCreateStoreCard(isDark),
                              const SizedBox(height: 12),
                              _buildStoresListCard(isDark),
                              const SizedBox(height: 12),
                              _buildCreateUserCard(isDark),
                              const SizedBox(height: 20),

                              // Header for Users List with Counts & Role Badges
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text(
                                          _isAmharic ? 'የተጠቃሚዎች ዝርዝር' : 'Team Members',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                          ),
                                          child: Text(
                                            '${_filteredUsers.length} / ${_users.length}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryBlue,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      AppStatusBadge.success(label: '$salesCount Sales'),
                                      AppStatusBadge.info(label: '$storekeeperCount Storekeepers'),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Search Bar for Users
                              AppSearchBar(
                                hintText: _isAmharic
                                    ? 'በስም፣ በስልክ ወይም በመደብር ይፈልጉ...'
                                    : 'Search by name, phone, or store...',
                                onChanged: (val) => setState(() => _searchQuery = val),
                                onClear: () => setState(() => _searchQuery = ''),
                              ),
                              const SizedBox(height: 8),

                              // Role Filter Chips
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildFilterChip('all', _isAmharic ? 'ሁሉም (${_users.length})' : 'All (${_users.length})'),
                                    const SizedBox(width: 6),
                                    _buildFilterChip('sales', _isAmharic ? 'ሽያጭ ($salesCount)' : 'Sales ($salesCount)'),
                                    const SizedBox(width: 6),
                                    _buildFilterChip('storekeeper', _isAmharic ? 'መጋዘን ($storekeeperCount)' : 'Storekeeper ($storekeeperCount)'),
                                    const SizedBox(width: 6),
                                    _buildFilterChip('active', _isAmharic ? 'ንቁ ($activeCount)' : 'Active ($activeCount)'),
                                    if (inactiveCount > 0) ...[
                                      const SizedBox(width: 6),
                                      _buildFilterChip('inactive', _isAmharic ? 'የታገደ ($inactiveCount)' : 'Blocked ($inactiveCount)'),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              if (_filteredUsers.isEmpty)
                                AppEmptyState(
                                  icon: Icons.person_search_outlined,
                                  title: _isAmharic ? 'ምንም ተጠቃሚ አልተገኘም' : 'No users found',
                                  subtitle: _isAmharic
                                      ? 'የፍለጋ ቃልዎን ይቀይሩ ወይም አዲስ ተጠቃሚ ይመዝግቡ'
                                      : 'Try adjusting your search query or add a new team account above',
                                )
                              else
                                ..._filteredUsers.map((u) => _buildUserCard(u, isDark)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterRole == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : null,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.primaryBlue,
      onSelected: (_) => setState(() => _filterRole = value),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildCreateStoreCard(bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(Icons.add_business_rounded, color: AppTheme.primaryBlue, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                _isAmharic ? 'አዲስ መደብር መፍጠር' : 'Create Store',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final field = TextField(
                controller: _storeNameController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _createStore(),
                decoration: InputDecoration(
                  labelText: LanguageService.t('storeName'),
                  hintText: 'e.g. Merkato Store',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
                ),
              );
              final button = SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isCreatingStore ? null : _createStore,
                  icon: _isCreatingStore
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_rounded, size: 18),
                  label: Text(LanguageService.t('create')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                  ),
                ),
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [field, const SizedBox(height: 10), button],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: field),
                  const SizedBox(width: 10),
                  button,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStoresListCard(bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: AppTheme.emeraldGreen, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isAmharic ? 'የነባር መደብሮች ዝርዝር (${_stores.length})' : 'Existing Stores (${_stores.length})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              AppStatusBadge.info(label: '${_stores.length} stores'),
            ],
          ),
          const SizedBox(height: 12),
          if (_stores.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  _isAmharic ? 'ምንም መደብር አልተፈጠረም። ከላይ አዲስ መደብር ይመዝግቡ።' : 'No stores created yet. Create your first store above.',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _stores.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
              itemBuilder: (context, index) {
                final store = _stores[index];
                final assignedUsers = _users.where((u) => u.storeId == store.id).toList();

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.12),
                        child: const Icon(
                          Icons.store_rounded,
                          size: 18,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (store.code.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                                      ),
                                    ),
                                    child: Text(
                                      store.code,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  assignedUsers.isEmpty
                                      ? (_isAmharic ? 'ምንም ሠራተኛ አልተመደበም' : 'No users assigned')
                                      : '${assignedUsers.length} ${_isAmharic ? "ሠራተኛ" : (assignedUsers.length > 1 ? "members" : "member")}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: assignedUsers.isEmpty
                                        ? (isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary)
                                        : AppTheme.emeraldGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 19, color: AppTheme.primaryBlue),
                        tooltip: 'Edit Store',
                        onPressed: () => _showEditStoreDialog(store),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppTheme.roseDanger),
                        tooltip: LanguageService.t('deleteStore'),
                        onPressed: () => _deleteStore(store),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCreateUserCard(bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _selectedRole == 'sales'
                            ? AppTheme.emeraldGreen.withValues(alpha: 0.12)
                            : AppTheme.primaryBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Icon(
                        _selectedRole == 'sales' ? Icons.point_of_sale_rounded : Icons.warehouse_rounded,
                        color: _selectedRole == 'sales' ? AppTheme.emeraldGreen : AppTheme.primaryBlue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedRole == 'sales'
                            ? (_isAmharic ? 'አዲስ የሽያጭ አካውንት ፍጠር' : 'Create Sales Account')
                            : (_isAmharic ? 'አዲስ የመጋዘን ኃላፊ ፍጠር' : 'Create Storekeeper Account'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _selectedRole == 'sales'
                  ? AppStatusBadge.success(label: 'SALES')
                  : AppStatusBadge.info(label: 'STOREKEEPER'),
            ],
          ),
          const SizedBox(height: 14),

          // Role Selector
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            decoration: InputDecoration(
              labelText: _isAmharic ? 'የአካውንት ሚና (Account Role) *' : 'Account Role *',
              prefixIcon: const Icon(Icons.badge_outlined, size: 20),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              filled: true,
              fillColor: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
            ),
            items: const [
              DropdownMenuItem(
                value: 'sales',
                child: Text('Sales (የሽያጭ ሠራተኛ)'),
              ),
              DropdownMenuItem(
                value: 'storekeeper',
                child: Text('Storekeeper (የመጋዘን ኃላፊ)'),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedRole = val);
            },
          ),
          const SizedBox(height: 10),

          // Name, Phone, Password
          AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _userNameController,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _isAmharic ? 'ሙሉ ስም (Full Name) *' : 'Full Name *',
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [
                    AutofillHints.telephoneNumber,
                    AutofillHints.username,
                  ],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _isAmharic ? 'ስልክ ቁጥር (Phone) *' : 'Phone Number *',
                    hintText: '0911111111',
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: _isAmharic ? 'የይለፍ ቃል (Password) *' : 'Password *',
                    hintText: _isAmharic ? 'ቢያንስ 6 ቁምፊዎች' : 'At least 6 characters',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Assign Stores (Searchable Multi-Store Selector)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storefront_rounded, size: 16, color: AppTheme.primaryBlue),
                        const SizedBox(width: 6),
                        Text(
                          _isAmharic ? 'መደብሮች መድብ (Select Multiple) *' : 'Assign Stores (Select Multiple) *',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                      ],
                    ),
                    Text(
                      '${_stores.length} ${_isAmharic ? "መደብሮች" : "stores"} | ${_selectedStoreIds.length} ${_isAmharic ? "ተመርጠዋል" : "selected"}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _selectedStoreIds.isEmpty ? AppTheme.roseDanger : AppTheme.emeraldGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Selected store chips with remove
                if (_selectedStoreIds.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _selectedStoreIds.map((sId) {
                      final storeMatch = _stores.where((s) => s.id == sId);
                      final sName = storeMatch.isNotEmpty ? storeMatch.first.name : sId;
                      return Chip(
                        label: Text(sName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        backgroundColor: AppTheme.primaryBlue.withValues(alpha: isDark ? 0.25 : 0.12),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          setState(() {
                            _selectedStoreIds.remove(sId);
                          });
                        },
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],

                // Checkboxes for all stores
                if (_stores.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      LanguageService.t('createStoreFirst'),
                      style: const TextStyle(fontSize: 12, color: AppTheme.roseDanger),
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _stores.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? AppTheme.darkBorder : const Color(0xFFF1F5F9)),
                      itemBuilder: (context, idx) {
                        final store = _stores[idx];
                        final isSelected = _selectedStoreIds.contains(store.id);
                        return CheckboxListTile(
                          value: isSelected,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppTheme.primaryBlue,
                          title: Text(
                            store.name,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          subtitle: store.code.isNotEmpty
                              ? Text(store.code, style: const TextStyle(fontSize: 10.5))
                              : null,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                if (!_selectedStoreIds.contains(store.id)) {
                                  _selectedStoreIds.add(store.id);
                                }
                              } else {
                                _selectedStoreIds.remove(store.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isCreatingUser ? null : _createStorekeeper,
              icon: _isCreatingUser
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text(
                _selectedRole == 'sales'
                    ? (_isAmharic ? '+ የሽያጭ አካውንት ፍጠር' : '+ Create Sales Account')
                    : (_isAmharic ? '+ የመጋዘን ኃላፊ አካውንት ፍጠር' : '+ Create Storekeeper Account'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedRole == 'sales'
                    ? AppTheme.emeraldGreen
                    : AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(AppUser user, bool isDark) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: user.active
                ? (user.isSales
                    ? AppTheme.emeraldGreen.withValues(alpha: 0.12)
                    : AppTheme.primaryBlue.withValues(alpha: 0.12))
                : (isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant),
            child: Icon(
              user.isSales
                  ? Icons.point_of_sale_rounded
                  : Icons.warehouse_rounded,
              size: 20,
              color: user.active
                  ? (user.isSales ? AppTheme.emeraldGreen : AppTheme.primaryBlue)
                  : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          decoration: user.active ? null : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    user.isSales
                        ? AppStatusBadge.success(label: 'SALES')
                        : AppStatusBadge.info(label: 'STOREKEEPER'),
                  ],
                ),
                const SizedBox(height: 5),
                // Display all assigned stores as chips
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    ..._stores
                        .where((s) => user.assignedStoreIds.contains(s.id) || s.id == user.storeId)
                        .map((s) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withValues(alpha: isDark ? 0.2 : 0.08),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.store_rounded, size: 11, color: AppTheme.primaryBlue),
                                  const SizedBox(width: 3),
                                  Text(
                                    s.name,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                    if (user.assignedStoreIds.isEmpty && user.storeId == null)
                      Text(
                        LanguageService.t('noStoreAssigned'),
                        style: const TextStyle(fontSize: 11, color: AppTheme.amberWarning, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 13,
                      color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user.phone ?? LanguageService.t('noPhone'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: user.active ? AppTheme.emeraldGreen : AppTheme.roseDanger,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user.active ? LanguageService.t('statusActive') : LanguageService.t('statusDeactivated'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: user.active ? AppTheme.emeraldGreen : AppTheme.roseDanger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 2,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryBlue),
                tooltip: 'Edit',
                onPressed: () => _showEditUserDialog(user),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.roseDanger),
                tooltip: LanguageService.t('delete'),
                onPressed: () => _deleteStorekeeper(user),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
