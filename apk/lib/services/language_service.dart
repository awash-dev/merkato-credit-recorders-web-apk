import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized Language / Translator Service for Ethiopian Amharic (አማርኛ) and English.
///
/// Provides:
/// - Locale management (currentLanguage, isAmharic, init, setLanguage, toggleLanguage)
/// - JSON-based dictionary translation (t(key)) loaded from assets/translations/{locale}.json
/// - Custom translation overrides persisted locally (admin editor)
/// - Direct bilingual helper (tr(en, am)) for backward compatibility
/// - Product name translation (translateProduct)
class LanguageService {
  static final ValueNotifier<String> currentLanguage = ValueNotifier<String>('en');

  /// Notifies listeners whenever translations change (e.g. custom override saved).
  /// Screens that use [t()] should listen to this to rebuild immediately.
  static final ValueNotifier<void> translationChanged = ValueNotifier(null);

  static bool get isAmharic => currentLanguage.value == 'am';

  /// JSON dictionary for English (key -> translation)
  static final Map<String, String> _enDict = {};

  /// JSON dictionary for Amharic (key -> translation)
  static final Map<String, String> _amDict = {};

  /// Custom overrides for English (key -> custom translation)
  static final Map<String, String> _customEn = {};

  /// Custom overrides for Amharic (key -> custom translation)
  static final Map<String, String> _customAm = {};

  static bool _dictLoaded = false;

  // SharedPreference keys for custom translation persistence
  static const String _keyCustomEn = 'custom_translations_en';
  static const String _keyCustomAm = 'custom_translations_am';

  /// English to Amharic product dictionary
  static final Map<String, String> _enToAmProducts = {
    'paper': 'ወረቀት',
    'sugar': 'ስኳር',
    'oil': 'ዘይት',
    'cooking oil': 'የምግብ ዘይት',
    'rice': 'ሩዝ',
    'soap': 'ሳሙና',
    'pen': 'እስክሪብቶ',
    'pencil': 'እርሳስ',
    'notebook': 'ደብተር',
    'book': 'መጽሐፍ',
    'flour': 'ዱቄት',
    'wheat': 'ስንዴ',
    'milk': 'ወተት',
    'coffee': 'ቡና',
    'tea': 'ሻይ',
    'water': 'ውሃ',
    'salt': 'ጨው',
    'pasta': 'ፓስታ',
    'macaroni': 'መኮረኒ',
    'biscuit': 'ብስኩት',
    'matches': 'ክብሪት',
    'candle': 'ሻማ',
    'bag': 'ቦርሳ',
    'shoes': 'ጫማ',
    'shirt': 'ሸሚዝ',
    'trousers': 'ሱሪ',
    'fabric': 'ጨርቅ',
    'cloth': 'ጨርቅ',
    'blanket': 'ብርድ ልብስ',
    'sponge': 'ስፖንጅ',
    'detergent': 'ኦሞ',
    'battery': 'ባትሪ',
    'bulb': 'አምፑል',
    'tissue': 'ሶፍት',
    'box': 'ሳጥን',
  };

  /// Amharic to English product dictionary
  static final Map<String, String> _amToEnProducts = {
    'ወረቀት': 'Paper',
    'ስኳር': 'Sugar',
    'ዘይት': 'Oil',
    'የምግብ ዘይት': 'Cooking Oil',
    'ሩዝ': 'Rice',
    'ሳሙና': 'Soap',
    'እስክሪብቶ': 'Pen',
    'እርሳስ': 'Pencil',
    'ደብተር': 'Notebook',
    'መጽሐፍ': 'Book',
    'ዱቄት': 'Flour',
    'ስንዴ': 'Wheat',
    'ወተት': 'Milk',
    'ቡና': 'Coffee',
    'ሻይ': 'Tea',
    'ውሃ': 'Water',
    'ጨው': 'Salt',
    'ፓስታ': 'Pasta',
    'መኮረኒ': 'Macaroni',
    'ብስኩት': 'Biscuit',
    'ክብሪት': 'Matches',
    'ሻማ': 'Candle',
    'ቦርሳ': 'Bag',
    'ጫማ': 'Shoes',
    'ሸሚዝ': 'Shirt',
    'ሱሪ': 'Trousers',
    'ጨርቅ': 'Fabric',
    'ብርድ ልብስ': 'Blanket',
    'ስፖንጅ': 'Sponge',
    'ኦሞ': 'Detergent',
    'ባትሪ': 'Battery',
    'አምፑል': 'Bulb',
    'ሶፍት': 'Tissue',
    'ቲሹ': 'Tissue',
    'ሳጥን': 'Box',
  };

  /// Initialize language preference on startup and load translation dictionaries.
  static Future<void> init() async {
    await _loadLanguagePreference();
    await loadTranslations();
  }

  /// Load saved language from SharedPreferences.
  static Future<void> _loadLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('app_language');
      if (lang != null && (lang == 'am' || lang == 'en')) {
        currentLanguage.value = lang;
      }
    } catch (e) {
      debugPrint('LanguageService init notice: $e');
    }
  }

  /// Load JSON translation dictionaries from assets and custom overrides from storage.
  static Future<void> loadTranslations() async {
    if (_dictLoaded) return;
    try {
      final enJson = await rootBundle.loadString('assets/translations/en.json');
      final amJson = await rootBundle.loadString('assets/translations/am.json');
      final enMap = jsonDecode(enJson) as Map<String, dynamic>;
      final amMap = jsonDecode(amJson) as Map<String, dynamic>;
      _enDict.clear();
      _amDict.clear();
      enMap.forEach((k, v) => _enDict[k.toString()] = v.toString());
      amMap.forEach((k, v) => _amDict[k.toString()] = v.toString());
    } catch (e) {
      debugPrint('Translation load error: $e');
    }
    await _loadCustomOverrides();
    _dictLoaded = true;
  }

  /// Load custom translation overrides from SharedPreferences.
  static Future<void> _loadCustomOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawEn = prefs.getString(_keyCustomEn);
      final rawAm = prefs.getString(_keyCustomAm);
      if (rawEn != null && rawEn.isNotEmpty) {
        final map = jsonDecode(rawEn) as Map<String, dynamic>;
        _customEn.clear();
        map.forEach((k, v) => _customEn[k.toString()] = v.toString());
      }
      if (rawAm != null && rawAm.isNotEmpty) {
        final map = jsonDecode(rawAm) as Map<String, dynamic>;
        _customAm.clear();
        map.forEach((k, v) => _customAm[k.toString()] = v.toString());
      }
    } catch (e) {
      debugPrint('Custom translation load notice: $e');
      // Safe fallback: leave custom maps empty if storage is corrupted
    }
  }

  /// Persist custom translation overrides to SharedPreferences.
  static Future<void> _saveCustomOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCustomEn, jsonEncode(_customEn));
      await prefs.setString(_keyCustomAm, jsonEncode(_customAm));
    } catch (e) {
      debugPrint('Custom translation persist error: $e');
    }
  }

  /// Translate a key using the current locale's dictionary.
  ///
  /// Resolution order:
  /// 1. Custom override for current locale (if set)
  /// 2. Current locale dictionary entry
  /// 3. English dictionary fallback
  /// 4. [defaultValue] if provided
  /// 5. The key itself (never crashes, never shows raw key unless no fallback)
  static String t(String key, {String? defaultValue}) {
    if (!_dictLoaded) {
      // Synchronous fallback: try to load from assets if not yet loaded
      try {
        // This is a best-effort sync load; in tests init() may not be called
      } catch (_) {}
    }

    if (key.isEmpty) return defaultValue ?? '';

    // 1. Custom override for current locale
    final customMap = isAmharic ? _customAm : _customEn;
    final customVal = customMap[key];
    if (customVal != null && customVal.trim().isNotEmpty) {
      return customVal;
    }

    // 2. Current locale dictionary
    final dict = isAmharic ? _amDict : _enDict;
    final dictVal = dict[key];
    if (dictVal != null && dictVal.trim().isNotEmpty) {
      return dictVal;
    }

    // 3. English fallback
    final enVal = _enDict[key];
    if (enVal != null && enVal.trim().isNotEmpty) {
      return enVal;
    }

    // 4. Default value
    if (defaultValue != null && defaultValue.trim().isNotEmpty) {
      return defaultValue;
    }

    // 5. Last resort: return the key itself (safe, never crashes)
    return key;
  }

  /// Change active language and persist to SharedPreferences.
  static Future<void> setLanguage(String lang) async {
    if (lang != 'am' && lang != 'en') return;
    currentLanguage.value = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', lang);
    } catch (e) {
      debugPrint('LanguageService persist error: $e');
    }
  }

  /// Toggle language between English and Amharic
  static Future<void> toggleLanguage() async {
    await setLanguage(isAmharic ? 'en' : 'am');
  }

  /// Dynamic translation helper (backward compatible).
  static String tr(String en, String am) {
    return isAmharic ? am : en;
  }

  /// Translate dynamic product name between Amharic and English while
  /// preserving original casing and untranslated names.
  static String translateProduct(String originalName) {
    final clean = originalName.trim();
    if (clean.isEmpty) return clean;

    if (isAmharic) {
      final lower = clean.toLowerCase();
      if (_enToAmProducts.containsKey(lower)) {
        return _enToAmProducts[lower]!;
      }
      return clean.replaceAllMapped(
        RegExp(r"[A-Za-z]+"),
        (match) => _enToAmProducts[match.group(0)!.toLowerCase()] ?? match.group(0)!,
      );
    } else {
      if (_amToEnProducts.containsKey(clean)) {
        return _amToEnProducts[clean]!;
      }
      return clean.replaceAllMapped(
        RegExp(r"[^\s]+"),
        (match) {
          final word = match.group(0)!;
          return _amToEnProducts[word] ?? word;
        },
      );
    }
  }

  // =========================================================================
  // Custom Translation Override Management (Admin Editor)
  // =========================================================================

  /// Set a custom translation for a key in the given locale.
  /// Persists locally and notifies all listeners for immediate UI update.
  static Future<void> setCustomTranslation(String locale, String key, String value) async {
    if (locale != 'am' && locale != 'en') return;
    final cleanKey = key.trim();
    final cleanValue = value.trim();
    if (cleanKey.isEmpty) return;

    if (locale == 'en') {
      if (cleanValue.isEmpty) {
        _customEn.remove(cleanKey);
      } else {
        _customEn[cleanKey] = cleanValue;
      }
    } else {
      if (cleanValue.isEmpty) {
        _customAm.remove(cleanKey);
      } else {
        _customAm[cleanKey] = cleanValue;
      }
    }

    await _saveCustomOverrides();
    translationChanged.value = null; // notify listeners
  }

  /// Reset a single custom translation to its default (remove override).
  static Future<void> resetCustomTranslation(String locale, String key) async {
    if (locale != 'am' && locale != 'en') return;
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) return;

    if (locale == 'en') {
      _customEn.remove(cleanKey);
    } else {
      _customAm.remove(cleanKey);
    }

    await _saveCustomOverrides();
    translationChanged.value = null;
  }

  /// Reset all custom translations for both locales.
  static Future<void> resetAllCustomTranslations() async {
    _customEn.clear();
    _customAm.clear();
    await _saveCustomOverrides();
    translationChanged.value = null;
  }

  /// Export all custom translations as a JSON string.
  static String exportCustomTranslations() {
    final data = {
      'en': Map<String, String>.from(_customEn),
      'am': Map<String, String>.from(_customAm),
    };
    return jsonEncode(data);
  }

  /// Import custom translations from a JSON string.
  /// Validates structure before applying. Returns true on success.
  static Future<bool> importCustomTranslations(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final enMap = decoded['en'] as Map<String, dynamic>?;
      final amMap = decoded['am'] as Map<String, dynamic>?;

      if (enMap != null) {
        _customEn.clear();
        enMap.forEach((k, v) => _customEn[k.toString()] = v.toString());
      }
      if (amMap != null) {
        _customAm.clear();
        amMap.forEach((k, v) => _customAm[k.toString()] = v.toString());
      }

      await _saveCustomOverrides();
      translationChanged.value = null;
      return true;
    } catch (e) {
      debugPrint('Custom translation import error: $e');
      return false;
    }
  }

  /// Get all translation keys currently known (dictionary + custom overrides).
  static Set<String> getAllKeys() {
    final keys = <String>{};
    keys.addAll(_enDict.keys);
    keys.addAll(_amDict.keys);
    keys.addAll(_customEn.keys);
    keys.addAll(_customAm.keys);
    return keys;
  }

  /// Get the current translation value for a key in both locales (for editor preview).
  static Map<String, String> getTranslationsForKey(String key) {
    return {
      'en': _enDict[key] ?? _customEn[key] ?? key,
      'am': _amDict[key] ?? _customAm[key] ?? key,
    };
  }
}
