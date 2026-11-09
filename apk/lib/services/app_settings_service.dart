import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'file_image_picker.dart';

class AppSettingsService {
  static const String _keyTitle = 'app_custom_title';
  static const String _keyLogo = 'app_custom_logo';
  static const String defaultTitle = 'Merkato Credit Record';
  static const String defaultTitleAm = 'መርካቶ የብድር መዝገብ';

  static final ValueNotifier<String> appTitleNotifier =
      ValueNotifier<String>(defaultTitle);

  /// Logo can be:
  /// - A Base64 string (from image upload, starts with "data:image" or "base64:")
  /// - An Image URL (starts with "http")
  /// - null (uses the 1 default application logo)
  static final ValueNotifier<String?> appLogoNotifier =
      ValueNotifier<String?>(null);

  static bool _initialized = false;

  static bool get hasCustomLogo {
    final v = appLogoNotifier.value;
    return v != null && v.trim().isNotEmpty;
  }

  static Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTitle = prefs.getString(_keyTitle);
      if (savedTitle != null && savedTitle.trim().isNotEmpty) {
        appTitleNotifier.value = savedTitle.trim();
      }
      final savedLogo = prefs.getString(_keyLogo);
      if (savedLogo != null && savedLogo.trim().isNotEmpty) {
        appLogoNotifier.value = savedLogo.trim();
      }
      _initialized = true;
    } catch (_) {}
  }

  static Future<void> setAppTitle(String title) async {
    final clean = title.trim();
    final valueToSave = clean.isEmpty ? defaultTitle : clean;
    appTitleNotifier.value = valueToSave;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyTitle, valueToSave);
    } catch (_) {}
  }

  static Future<void> setAppLogo(String? logo) async {
    final clean = logo?.trim();
    appLogoNotifier.value = (clean == null || clean.isEmpty) ? null : clean;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (clean == null || clean.isEmpty) {
        await prefs.remove(_keyLogo);
      } else {
        await prefs.setString(_keyLogo, clean);
      }
    } catch (_) {}
  }

  /// Pick an image file from the device gallery/files and save as custom logo (Base64)
  static Future<bool> pickAndSaveLogo() async {
    try {
      final bytes = await pickImageBytes();
      if (bytes != null && bytes.isNotEmpty) {
        final base64String = 'data:image/png;base64,${base64Encode(bytes)}';
        await setAppLogo(base64String);
        return true;
      }
    } catch (e) {
      debugPrint('Error picking logo image: $e');
      rethrow;
    }
    return false;
  }

  /// Resets to the 1 default logo
  static Future<void> resetToDefaultLogo() async {
    await setAppLogo(null);
  }

  static Uint8List? getLogoBytes() {
    final raw = appLogoNotifier.value;
    if (raw == null || raw.isEmpty) return null;
    try {
      String clean = raw;
      if (clean.startsWith('data:image')) {
        final comma = clean.indexOf(',');
        if (comma != -1) {
          clean = clean.substring(comma + 1);
        }
      } else if (clean.startsWith('base64:')) {
        clean = clean.substring(7);
      }
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  static Widget buildLogoWidget({
    double size = 32,
    Color? fallbackColor,
    BorderRadius? borderRadius,
  }) {
    return ValueListenableBuilder<String?>(
      valueListenable: appLogoNotifier,
      builder: (context, logoData, _) {
        final radius = borderRadius ?? BorderRadius.circular(8);

        if (logoData != null && logoData.isNotEmpty) {
          // 1. Check if it's base64 image data (uploaded file)
          final bytes = getLogoBytes();
          if (bytes != null && bytes.isNotEmpty) {
            return ClipRRect(
              borderRadius: radius,
              child: Image.memory(
                bytes,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackIcon(size, fallbackColor, radius),
              ),
            );
          }

          // 2. Check if it's a web URL
          if (logoData.startsWith('http://') || logoData.startsWith('https://')) {
            return ClipRRect(
              borderRadius: radius,
              child: Image.network(
                logoData,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackIcon(size, fallbackColor, radius),
              ),
            );
          }
        }

        // 3. One default logo (can be updated at any time by uploading an image)
        return _buildFallbackIcon(size, fallbackColor, radius);
      },
    );
  }

  static Widget _buildFallbackIcon(double size, Color? color, BorderRadius radius) {
    return ClipRRect(
      borderRadius: radius,
      child: Image.asset(
        'assets/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: (color ?? const Color(0xFF2563EB)).withValues(alpha: 0.12),
            borderRadius: radius,
          ),
          child: Icon(
            Icons.storefront_rounded,
            color: color ?? const Color(0xFF2563EB),
            size: size * 0.58,
          ),
        ),
      ),
    );
  }
}

