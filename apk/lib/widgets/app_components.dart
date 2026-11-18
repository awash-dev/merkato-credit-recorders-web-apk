import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/language_service.dart';

/// Reusable UI component library for Merkato Credit Record.

/// Premium Card with consistent border, elevation, and background
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final VoidCallback? onTap;
  final BorderSide? borderSide;
  final double? borderRadius;
  final bool hasShadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.onTap,
    this.borderSide,
    this.borderRadius,
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = borderRadius ?? AppTheme.radiusLg;

    final cardContent = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? (isDark ? AppTheme.darkSurface : AppTheme.lightSurface),
        borderRadius: BorderRadius.circular(r),
        border: Border.fromBorderSide(
          borderSide ??
              BorderSide(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                width: 1.0,
              ),
        ),
        boxShadow: hasShadow ? AppTheme.cardShadow(isDark) : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(r),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16.0),
            child: child,
          ),
        ),
      ),
    );

    return cardContent;
  }
}

/// Financial KPI Metric Card with left color accent, modern typography, and icon badge
class AppMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;
  final String? currency;
  final VoidCallback? onTap;

  const AppMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.accentColor,
    this.currency,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.0,
        ),
        boxShadow: AppTheme.softShadow(isDark),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Stack(
            children: [
              // Left accent strip
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppTheme.radiusMd),
                      bottomLeft: Radius.circular(AppTheme.radiusMd),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top: Title and Icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                              height: 1.25,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(
                              alpha: isDark ? 0.20 : 0.12,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 14, color: accentColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Middle: Value
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          if (currency != null) ...[
                            Text(
                              currency!,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            value,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.lightTextPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom: Subtitle
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppTheme.darkTextTertiary
                              : AppTheme.lightTextTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modern Status Badge Pill (Paid, Pending, Credit Due, Stocked, etc.)
class AppStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool isDense;

  const AppStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.isDense = false,
  });

  factory AppStatusBadge.success({required String label, IconData? icon, bool isDense = false}) {
    return AppStatusBadge(
      label: label,
      color: AppTheme.emeraldGreen,
      icon: icon,
      isDense: isDense,
    );
  }

  factory AppStatusBadge.info({required String label, IconData? icon, bool isDense = false}) {
    return AppStatusBadge(
      label: label,
      color: AppTheme.primaryBlue,
      icon: icon,
      isDense: isDense,
    );
  }

  factory AppStatusBadge.danger({required String label, IconData? icon, bool isDense = false}) {
    return AppStatusBadge(
      label: label,
      color: AppTheme.roseDanger,
      icon: icon,
      isDense: isDense,
    );
  }

  factory AppStatusBadge.warning({required String label, IconData? icon, bool isDense = false}) {
    return AppStatusBadge(
      label: label,
      color: AppTheme.amberWarning,
      icon: icon,
      isDense: isDense,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDense ? 7 : 9,
        vertical: isDense ? 2.5 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.40 : 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: isDense ? 10 : 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: isDense ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modern Search Bar with Clear Icon and Focus State
class AppSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const AppSearchBar({
    super.key,
    this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late TextEditingController _effectiveController;
  bool _createdInternal = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _effectiveController = widget.controller!;
    } else {
      _effectiveController = TextEditingController();
      _createdInternal = true;
    }
  }

  @override
  void didUpdateWidget(covariant AppSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (_createdInternal) {
        _effectiveController.dispose();
        _createdInternal = false;
      }
      if (widget.controller != null) {
        _effectiveController = widget.controller!;
      } else {
        _effectiveController = TextEditingController();
        _createdInternal = true;
      }
    }
  }

  @override
  void dispose() {
    if (_createdInternal) {
      _effectiveController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.0,
        ),
        boxShadow: AppTheme.softShadow(isDark),
      ),
      child: TextField(
        controller: _effectiveController,
        onChanged: widget.onChanged,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.hintText,
          hintStyle: TextStyle(
            fontSize: 12.5,
            color: isDark
                ? AppTheme.darkTextTertiary
                : AppTheme.lightTextTertiary,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 19,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
          suffixIcon: _effectiveController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                  onPressed: () {
                    _effectiveController.clear();
                    if (widget.onClear != null) {
                      widget.onClear!();
                    } else if (widget.onChanged != null) {
                      widget.onChanged!('');
                    }
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 11,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

/// Clean, polished Empty State with illustration icon and action button
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.subtitle,
    this.buttonLabel,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bodyText = message ?? subtitle ?? '';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.darkSurfaceAlt : AppTheme.lightSurfaceAlt),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  width: 1.5,
                ),
              ),
              child: Icon(
                icon,
                size: 34,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
              ),
            ),
            if (bodyText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                bodyText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: isDark
                      ? AppTheme.darkTextTertiary
                      : AppTheme.lightTextTertiary,
                  height: 1.35,
                ),
              ),
            ],
            if (buttonLabel != null && onButtonPressed != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onButtonPressed,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Language Selector Pill (English / አማርኛ)
class AppLanguagePill extends StatelessWidget {
  final VoidCallback? onToggle;

  const AppLanguagePill({super.key, this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAmharic = LanguageService.isAmharic;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceAlt : AppTheme.lightSurfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onTap: () async {
            await LanguageService.setLanguage(isAmharic ? 'en' : 'am');
            if (onToggle != null) onToggle!();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.translate_rounded,
                  size: 14,
                  color: isDark ? AppTheme.primaryBlueDark : AppTheme.primaryBlue,
                ),
                const SizedBox(width: 5),
                Text(
                  isAmharic ? 'EN' : 'አማ',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
