import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/neon_database_service.dart';
import '../services/language_service.dart';
import '../theme/app_theme.dart';
import '../widgets/telebirr_background.dart';
import '../widgets/app_components.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isAmharic => LanguageService.isAmharic;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString('last_login_phone') ?? '';
      final savedPassword = prefs.getString('saved_password') ?? '';
      final remember = prefs.getBool('remember_password') ?? true;

      if (mounted) {
        setState(() {
          _rememberPassword = remember;
          if (savedPhone.isNotEmpty) {
            _phoneController.text = savedPhone;
          }
          if (remember && savedPassword.isNotEmpty) {
            _passwordController.text = savedPassword;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading saved credentials: $e');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty) {
      setState(() {
        _errorMessage = LanguageService.t('pleaseEnterPhone');
      });
      return;
    }

    if (NeonDatabaseService.normalizePhone(phone) == null) {
      setState(() {
        _errorMessage =
            LanguageService.t('validEthiopianPhone');
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorMessage = LanguageService.t('pleaseEnterPassword');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ApiService.login(phone, password);

      // Trigger OS Password Manager prompt (Samsung Pass, Google Autofill, iOS Keychain, Browser)
      TextInput.finishAutofillContext(shouldSave: _rememberPassword);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_login_phone', phone);
      await prefs.setBool('remember_password', _rememberPassword);
      if (_rememberPassword) {
        await prefs.setString('saved_password', password);
      } else {
        await prefs.remove('saved_password');
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainScreen(currentUser: user)),
      );
    } catch (e) {
      // Don't save wrong password to password manager
      TextInput.finishAutofillContext(shouldSave: false);

      final msg = e.toString().replaceAll('Exception:', '').trim();
      setState(() {
        if (msg.contains('Socket') ||
            msg.contains('Failed host lookup') ||
            msg.contains('ClientException') ||
            msg.contains('timeout') ||
            msg.contains('No address associated with hostname')) {
          _errorMessage = LanguageService.t('networkError');
        } else {
          _errorMessage = msg;
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0),
            child: AppLanguagePill(
              onToggle: () => setState(() {}),
            ),
          ),
        ],
      ),
      body: TelebirrBackground(
        isDark: isDark,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Icon & Header
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF2563EB),
                              Color(0xFF1D4ED8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      LanguageService.t('appName', defaultValue: 'Merkato Credit Record'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isAmharic
                          ? 'የፋይናንስና የዕዳ መዝገብ አስተዳደር'
                          : 'Modern Business Credit & Ledger',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Login Card
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 26.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                LanguageService.t('signIn'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.roseDangerLight,
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                border: Border.all(
                                  color: AppTheme.roseDanger.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: AppTheme.roseDanger,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.roseDangerDark,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],

                          // AutofillGroup enables Samsung Pass, Google Password Manager, Apple Keychain, and browser autofill
                          AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Phone Number
                                TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                                  ),
                                  cursorColor: AppTheme.primaryBlue,
                                  autofillHints: const [
                                    AutofillHints.username,
                                    AutofillHints.telephoneNumber,
                                  ],
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9+\-() ]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: LanguageService.t('phoneNumber'),
                                    hintText: LanguageService.t('e.gAhmed'),
                                    prefixIcon: Icon(
                                      Icons.phone_iphone_rounded,
                                      size: 20,
                                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Password Field
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                                  ),
                                  cursorColor: AppTheme.primaryBlue,
                                  autofillHints: const [
                                    AutofillHints.password,
                                  ],
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _handleLogin(),
                                  decoration: InputDecoration(
                                    labelText: LanguageService.t('password'),
                                    hintText: '••••••••',
                                    prefixIcon: Icon(
                                      Icons.lock_outline_rounded,
                                      size: 20,
                                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 20,
                                        color: isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.lightTextSecondary,
                                      ),
                                      onPressed: () {
                                        setState(
                                          () => _obscurePassword = !_obscurePassword,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Save / Remember Password Option
                          InkWell(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            onTap: () {
                              setState(() {
                                _rememberPassword = !_rememberPassword;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: Checkbox(
                                      value: _rememberPassword,
                                      activeColor: AppTheme.primaryBlue,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          _rememberPassword = val ?? true;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          LanguageService.t('savePassword', defaultValue: 'Save password'),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                            border: Border.all(
                                              color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: const Text(
                                            'Samsung / Google',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.primaryBlue,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Submit Button
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          LanguageService.t('signIn'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.arrow_forward_rounded, size: 18),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Security Trust Footer
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isAmharic
                                ? 'የተጠበቀ የፋይናንስ ዳታ · Bank-Grade Encryption'
                                : 'Protected Business Data · Encrypted',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
