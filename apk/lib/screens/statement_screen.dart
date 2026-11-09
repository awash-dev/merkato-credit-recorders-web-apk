import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:et_date_picker/et_date_picker.dart';

import '../models/statement.dart';
import '../models/ledger_record.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/app_settings_service.dart';
import '../services/ethiopian_calendar.dart';
import '../services/file_saver.dart';
import '../widgets/telebirr_background.dart';

class StatementScreen extends StatefulWidget {
  final String accountName;
  final String accountType; // 'customer' | 'supplier'
  final String? storeId;

  const StatementScreen({
    super.key,
    required this.accountName,
    required this.accountType,
    this.storeId,
  });

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  bool get _isAmharic => LanguageService.isAmharic;
  AccountStatement? _statement;
  bool _isLoading = true;
  String? _error;
  final GlobalKey _tableKey = GlobalKey();

  // Inline Excel Editing state
  int? _inlineEditingIndex;
  late TextEditingController _inlineDescController;
  late TextEditingController _inlineQtyController;
  late TextEditingController _inlinePriceController;
  late TextEditingController _inlineDateController;
  String _inlineRawDate = '';
  bool _isSavingInline = false;

  @override
  void initState() {
    super.initState();
    _inlineDescController = TextEditingController();
    _inlineQtyController = TextEditingController();
    _inlinePriceController = TextEditingController();
    _inlineDateController = TextEditingController();
    _loadStatement();
  }

  @override
  void dispose() {
    _inlineDescController.dispose();
    _inlineQtyController.dispose();
    _inlinePriceController.dispose();
    _inlineDateController.dispose();
    super.dispose();
  }

  /// Converts any Gregorian or ISO date string into an authentic Ethiopian calendar date
  String _formatEthiopianDate(String rawDate) {
    return EthiopianCalendar.formatAnyDate(rawDate, lang: _isAmharic ? 'am' : 'en');
  }

  Future<void> _loadStatement() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final st = await ApiService.getStatement(
        name: widget.accountName,
        type: widget.accountType,
        storeId: widget.storeId,
      );
      if (mounted) {
        setState(() {
          _statement = st;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Captures the complete branded statement card as a high-resolution PNG image and saves / shares it
  Future<void> _captureTableScreenshot({bool share = true}) async {
    try {
      final boundary =
          _tableKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      final cleanName = widget.accountName.replaceAll(' ', '_');
      final filename = 'statement-$cleanName.png';

      await shareOrSaveImageBytes(
        pngBytes,
        filename,
        title: '${widget.accountName} - Statement',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isAmharic
                        ? 'የመግለጫው ምስል ($filename) በተሳካ ሁኔታ ተዘጋጅቷል/ተጋርቷል!'
                        : 'Statement image ($filename) shared / saved successfully!',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Screenshot capture: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Opens social media sharing sheet: automatically captures the table screenshot and offers Telegram/Social share as an image, or Full PDF
  Future<void> _shareStatement() async {
    if (_statement == null) return;
    final st = _statement!;

    // Automatically capture high-resolution complete statement screenshot immediately
    Uint8List? tableImageBytes;
    try {
      final boundary =
          _tableKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          tableImageBytes = byteData.buffer.asUint8List();
        }
      }
    } catch (e) {
      debugPrint('Auto screenshot capture: $e');
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final cardColor = isDark ? const Color(0xFF1B2234) : Colors.white;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.share_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    _isAmharic ? 'መግለጫውን ለቴሌግራም / ማህበራዊ ሚዲያ አጋራ' : 'Share to Telegram / Social Apps',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 1. Share Automatically Captured Statement directly as a PNG Image
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.image_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                title: Text(
                  _isAmharic ? 'የሰንጠረዥ ምስል ለቴሌግራም/ዋትስአፕ አጋራ (PNG Image)' : 'Share Statement Image (PNG)',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  _isAmharic
                      ? 'ንጹሕ እና ሙሉ የሂሳብ መግለጫ ምስል በቀጥታ ይልካል'
                      : 'Complete branded statement card image for Telegram/WhatsApp',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (tableImageBytes != null) {
                    final cleanName = st.accountName.replaceAll(' ', '_');
                    final filename = 'statement-$cleanName.png';
                    await shareOrSaveImageBytes(
                      tableImageBytes,
                      filename,
                      title: '${st.accountName} - Statement',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _isAmharic
                                      ? 'የመግለጫው ምስል ($filename) በተሳካ ሁኔታ ተጋርቷል/ወርዷል!'
                                      : 'Statement image ($filename) shared / downloaded successfully!',
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF16A34A),
                          duration: const Duration(seconds: 3),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } else {
                    _captureTableScreenshot(share: true);
                  }
                },
              ),

              const Divider(height: 1),

              // 2. Share Full Official PDF Document
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626), size: 22),
                ),
                title: Text(
                  _isAmharic ? 'ሙሉ ፒዲኤፍ ሰነድ አጋራ' : 'Share Full PDF Document',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  _isAmharic
                      ? 'የንግድ ሎጎ፣ ርዕስ እና ሙሉ የሂሳብ ዝርዝር የያዘ ፒዲኤፍ'
                      : 'Complete official document with logo & header',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _printOrExportPdf(shareOnly: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _startInlineEdit(int index, StatementEntry entry) {
    setState(() {
      _inlineEditingIndex = index;
      _inlineDescController.text = entry.description;
      final q = entry.quantity;
      _inlineQtyController.text = q > 0 ? (q % 1 == 0 ? q.toInt().toString() : q.toString()) : '1';
      final p = entry.unitPrice;
      final fallbackAmt = entry.debit > 0 ? entry.debit : entry.credit;
      _inlinePriceController.text = p > 0 ? p.toStringAsFixed(2) : (fallbackAmt > 0 ? fallbackAmt.toStringAsFixed(2) : '');
      _inlineRawDate = entry.date;
      _inlineDateController.text = _formatEthiopianDate(entry.date);
      _isSavingInline = false;
    });
  }

  Future<void> _pickInlineEthiopianDate() async {
    DateTime initDate = DateTime.now();
    final dt = DateTime.tryParse(_inlineRawDate);
    if (dt != null) initDate = dt;

    final result = await showEthiopianDatePickerDialog(
      context: context,
      initialDate: initDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      showSelectedDatePreview: true,
      useEthiopicNumerals: _isAmharic,
      cancelText: _isAmharic ? 'ሰርዝ' : 'Cancel',
      confirmText: _isAmharic ? 'ይሁን' : 'OK',
    );
    if (result == null) return;
    final picked = result.gregorianDate;
    final eth = EthiopianCalendar.toEthiopian(
      picked.year,
      picked.month,
      picked.day,
    );
    setState(() {
      _inlineRawDate =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _inlineDateController.text = EthiopianCalendar.formatDisplay(
        eth,
        lang: _isAmharic ? 'am' : 'en',
      );
    });
  }

  Future<void> _saveInlineEdit(StatementEntry entry) async {
    setState(() => _isSavingInline = true);
    try {
      String effectiveRecordId = entry.recordId ?? '';
      if (effectiveRecordId.isEmpty) {
        final records = await ApiService.getRecords(
          type: widget.accountType,
          storeId: widget.storeId,
        );
        final target = widget.accountName.trim().toLowerCase();
        final matched = records.firstWhere(
          (r) => r.title.trim().toLowerCase() == target,
          orElse: () =>
              LedgerRecord(id: '', type: '', title: '', date: '', items: []),
        );
        effectiveRecordId = matched.id;
      }

      final q = double.tryParse(_inlineQtyController.text.trim()) ?? 0;
      final p = double.tryParse(_inlinePriceController.text.trim()) ?? 0;
      final saveDate =
          _inlineRawDate.isNotEmpty ? _inlineRawDate : entry.date;

      await ApiService.updateStatementEntry(
        recordId: effectiveRecordId,
        itemId: entry.id ?? '',
        description: _inlineDescController.text.trim(),
        quantity: q,
        unitPrice: p,
        date: saveDate,
        bank: entry.bank,
        notes: entry.notes,
      );

      if (mounted) {
        setState(() {
          _inlineEditingIndex = null;
          _isSavingInline = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isAmharic
                  ? 'ረድፉ በሰንጠረዡ ውስጥ በቀጥታ ተስተካክሏል'
                  : 'Row updated directly in table!',
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 2),
          ),
        );
        _loadStatement();
      }
    } catch (err) {
      if (mounted) {
        setState(() => _isSavingInline = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildInlineEditRow(
    StatementEntry entry,
    Color gridColor,
    bool isDark,
  ) {
    final q = double.tryParse(_inlineQtyController.text.trim()) ?? 0;
    final p = double.tryParse(_inlinePriceController.text.trim()) ?? 0;
    final subtotal = q > 0 && p > 0
        ? q * p
        : (entry.debit > 0 ? entry.debit : entry.credit);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 14,
                child: TextField(
                  controller: _inlineDescController,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: _isAmharic ? 'የዕቃው ስም' : 'Item Description',
                    labelStyle: const TextStyle(fontSize: 10),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 9,
                child: InkWell(
                  onTap: _pickInlineEthiopianDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _inlineDateController.text.isEmpty
                                ? _formatEthiopianDate(entry.date)
                                : _inlineDateController.text,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF334155),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 14,
                          color: Color(0xFF2563EB),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 58,
                child: TextField(
                  controller: _inlineQtyController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: _isAmharic ? 'ብዛት' : 'Qty',
                    labelStyle: const TextStyle(fontSize: 10),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'x',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _inlinePriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: _isAmharic ? 'ዋጋ' : 'Price',
                    labelStyle: const TextStyle(fontSize: 10),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blueAccent.shade100),
                  ),
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'ETB ${_currencyFormat.format(subtotal)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _isSavingInline
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF16A34A),
                        size: 28,
                      ),
                      tooltip: _isAmharic ? 'አስቀምጥ' : 'Save',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _saveInlineEdit(entry),
                    ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Icons.cancel_rounded,
                  color: Colors.grey.shade500,
                  size: 24,
                ),
                tooltip: _isAmharic ? 'ሰርዝ' : 'Cancel',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _inlineEditingIndex = null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _printOrExportPdf({bool shareOnly = false}) async {
    if (_statement == null) return;
    final st = _statement!;

    pw.Font? ethiopicRegular;
    pw.Font? ethiopicBold;
    try {
      ethiopicRegular = await PdfGoogleFonts.notoSansEthiopicRegular();
      ethiopicBold = await PdfGoogleFonts.notoSansEthiopicBold();
    } catch (e) {
      debugPrint('Google Fonts load error: $e');
    }

    final pdf = pw.Document();
    final logoBytes = AppSettingsService.getLogoBytes();
    final customTitle = AppSettingsService.appTitleNotifier.value;
    final dateDisplay = _isAmharic
        ? EthiopianCalendar.formatDisplay(EthiopianCalendar.now(), lang: 'am')
        : EthiopianCalendar.formatDisplay(EthiopianCalendar.now(), lang: 'en');
    final timeDisplay = DateFormat('HH:mm').format(DateTime.now());

    final themeData = ethiopicRegular != null
        ? pw.ThemeData.withFont(
            base: ethiopicRegular,
            bold: ethiopicBold ?? ethiopicRegular,
          )
        : null;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        theme: themeData,
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 16),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  customTitle,
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // Elegant Header Bar
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logoBytes != null) ...[
                      pw.Container(
                        width: 44,
                        height: 44,
                        margin: const pw.EdgeInsets.only(right: 12),
                        decoration: pw.BoxDecoration(
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                        ),
                        child: pw.ClipRRect(
                          horizontalRadius: 7,
                          verticalRadius: 7,
                          child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.cover),
                        ),
                      ),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          customTitle,
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey900,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          st.storeName.isEmpty
                              ? (_isAmharic ? 'የሂሳብ መግለጫ' : 'Account Statement')
                              : '${st.storeName} · ${_isAmharic ? 'የሂሳብ መግለጫ' : 'Account Statement'}',
                          style: const pw.TextStyle(
                            fontSize: 9.5,
                            color: PdfColors.blueGrey600,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue50,
                            borderRadius: pw.BorderRadius.circular(4),
                            border: pw.Border.all(color: PdfColors.blue200, width: 0.6),
                          ),
                          child: pw.Text(
                            '${_isAmharic ? 'የሂሳብ ስም' : 'Account'}: ${st.accountName} (${st.accountType.toUpperCase()})',
                            style: pw.TextStyle(
                              fontSize: 9.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      _isAmharic ? 'ቀን፦ $dateDisplay ($timeDisplay)' : 'Date: $dateDisplay ($timeDisplay)',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                      ),
                      child: pw.Text(
                        'Currency: ETB',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Divider(thickness: 0.8, color: PdfColors.grey300),
            pw.SizedBox(height: 10),

            // Excel-style Statement Table
            pw.TableHelper.fromTextArray(
              headers: [
                _isAmharic ? 'ቀን' : 'Date',
                _isAmharic ? 'የዕቃው ዝርዝር' : 'Item Description',
                _isAmharic ? 'ብዛት x ዋጋ' : 'Qty x Price',
                _isAmharic ? 'ተቀባይ (+)' : 'Debit (+)',
                _isAmharic ? 'ተከፋይ (-)' : 'Credit (-)',
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF1E293B),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
              headerPadding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 7),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.6),
                ),
              ),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF8FAFC),
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.6),
                ),
              ),
              data: st.entries.map((entry) {
                final qtyPrice = (entry.quantity > 0 && entry.unitPrice > 0)
                    ? '${entry.quantity % 1 == 0 ? entry.quantity.toInt().toString() : entry.quantity.toString()} pcs x ${_currencyFormat.format(entry.unitPrice)}'
                    : '-';
                return [
                  _formatEthiopianDate(entry.date),
                  entry.description + (entry.bank != null ? ' [${entry.bank}]' : ''),
                  qtyPrice,
                  entry.debit > 0 ? _currencyFormat.format(entry.debit) : '-',
                  entry.credit > 0 ? _currencyFormat.format(entry.credit) : '-',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 12),

            // Modern Statement Totals Box
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _isAmharic
                            ? 'ጠቅላላ ግብይቶች (${st.entries.length} መዝገቦች)'
                            : 'TOTALS (${st.entries.length} entries)',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                          color: PdfColors.blueGrey800,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        '${_isAmharic ? 'ጠቅላላ ተቀባይ' : 'Total Debit'}: ETB ${_currencyFormat.format(st.totals.totalDebit)}',
                        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '${_isAmharic ? 'ጠቅላላ ተከፋይ' : 'Total Credit'}: ETB ${_currencyFormat.format(st.totals.totalCredit)}',
                        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: st.totals.outstanding > 0 ? const PdfColor.fromInt(0xFFFEF2F2) : const PdfColor.fromInt(0xFFF0FDF4),
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(
                        color: st.totals.outstanding > 0 ? const PdfColor.fromInt(0xFFFCA5A5) : const PdfColor.fromInt(0xFF86EFAC),
                        width: 1,
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          _isAmharic ? 'የተጣራ ቀሪ ሂሳብ' : 'OUTSTANDING BALANCE',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: st.totals.outstanding > 0 ? PdfColors.red900 : PdfColors.green900,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'ETB ${_currencyFormat.format(st.totals.outstanding)}',
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: st.totals.outstanding > 0 ? const PdfColor.fromInt(0xFFDC2626) : const PdfColor.fromInt(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    if (shareOnly) {
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'statement-${st.accountName.replaceAll(' ', '_')}.pdf',
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'statement-${st.accountName.replaceAll(' ', '_')}.pdf',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        title: Text(
          widget.accountName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: 0.5,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          if (_statement != null) ...[
            // 1. Export / Print PDF Statement
            IconButton(
              icon: const Icon(Icons.print_outlined, size: 20),
              tooltip: _isAmharic ? 'መግለጫ አትም / ፒዲኤፍ' : 'Print / Export PDF',
              onPressed: () => _printOrExportPdf(shareOnly: false),
            ),

            // 2. Share Menu (Camera/Screenshot & PDF merged into 1 one-click action)
            IconButton(
              icon: const Icon(Icons.share_outlined, size: 20),
              tooltip: _isAmharic
                  ? 'ምስል አንሳና ለቴሌግራም/ዋትስአፕ አጋራ'
                  : 'Capture & Share Statement',
              onPressed: _shareStatement,
            ),
          ],
        ],
      ),
      body: TelebirrBackground(
        isDark: isDark,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
            : _statement == null || _statement!.entries.isEmpty
            ? Center(
                child: Text(
                  _isAmharic
                      ? 'ምንም የግብይት መዝገብ አልተገኘም'
                      : 'No transaction records found for this account.',
                ),
              )
            : _buildStatementContent(_statement!),
      ),
    );
  }

  Widget _buildStatementShareHeader(AccountStatement st) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final customTitle = AppSettingsService.appTitleNotifier.value;
    final dateDisplay = _isAmharic
        ? EthiopianCalendar.formatDisplay(EthiopianCalendar.now(), lang: 'am')
        : EthiopianCalendar.formatDisplay(EthiopianCalendar.now(), lang: 'en');
    final timeDisplay = DateFormat('HH:mm').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppSettingsService.buildLogoWidget(size: 36),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (st.storeName.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        st.storeName,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$dateDisplay ($timeDisplay)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      width: 0.8,
                    ),
                  ),
                  child: const Text(
                    'Currency: ETB',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_isAmharic ? 'የሂሳብ ስም' : 'Account'}: ${st.accountName}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
              Text(
                st.accountType.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatementContent(AccountStatement st) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(10.0),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // RepaintBoundary wraps the entire styled statement presentation:
            // Header + Table + Totals so the captured image is a complete, beautiful branded document!
            RepaintBoundary(
              key: _tableKey,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141926) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatementShareHeader(st),
                    const SizedBox(height: 10),
                    _buildMobileExcelTable(st),
                    const SizedBox(height: 10),
                    _buildExcelTotalsCard(st),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Authentic Excel Table perfectly fitted to small mobile screens with real spreadsheet gridlines
  /// (Balance column removed to give spacious layout; click row to edit in Excel mode)
  Widget _buildMobileExcelTable(AccountStatement st) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gridColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFCBD5E1);
    final isStock = st.accountType == 'stock';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: gridColor, width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Excel Header Row (Classic Spreadsheet Header: Date, Item, Debit, Credit)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                border: Border(
                  bottom: BorderSide(color: gridColor, width: 1.2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: gridColor, width: 0.8),
                        ),
                      ),
                      child: Text(
                        _isAmharic ? 'ቀን' : 'Date',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 15,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: gridColor, width: 0.8),
                        ),
                      ),
                      child: Text(
                        _isAmharic ? 'ዕቃ' : 'Item',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: gridColor, width: 0.8),
                        ),
                      ),
                      child: Text(
                        isStock
                            ? (_isAmharic ? 'ገቢ (+)' : 'Stock In (+)')
                            : (_isAmharic ? 'ተቀባይ (+)' : 'Debit (+)'),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        isStock
                            ? (_isAmharic ? 'ወጪ (-)' : 'Stock Out (-)')
                            : (_isAmharic ? 'ተከፋይ (-)' : 'Credit (-)'),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Excel Data Rows with Gridlines (Clickable to Edit Excel-Style)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: st.entries.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, thickness: 0.8, color: gridColor),
              itemBuilder: (context, index) {
                final entry = st.entries[index];
                if (_inlineEditingIndex == index) {
                  return _buildInlineEditRow(entry, gridColor, isDark);
                }

                final isEven = index % 2 == 0;

                final rowBg = isEven
                    ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                    : (isDark
                          ? const Color(0xFF18181B)
                          : const Color(0xFFF8FAFC));

                return InkWell(
                  onTap: () => _startInlineEdit(index, entry),
                  child: Container(
                    color: rowBg,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Col 1: Date (Ethiopian Calendar)
                        Expanded(
                          flex: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: gridColor, width: 0.8),
                              ),
                            ),
                            child: Text(
                              _formatEthiopianDate(entry.date),
                              style: TextStyle(
                                fontSize: 9.5,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),

                        // Col 2: Description & Qty x Price (NO TRUNCATION, uses 'x' instead of '@')
                        Expanded(
                          flex: 15,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: gridColor, width: 0.8),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.description,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                    height: 1.25,
                                  ),
                                  softWrap: true, // FULL NAME ALWAYS VISIBLE
                                ),
                                if (entry.quantity > 0 && entry.unitPrice > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      '${entry.quantity.toInt()} pcs x ${_currencyFormat.format(entry.unitPrice)}',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  )
                                else if (entry.bank != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      '[${entry.bank}]',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Col 3: Debit
                        Expanded(
                          flex: 7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: gridColor, width: 0.8),
                              ),
                            ),
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                entry.debit > 0
                                    ? _currencyFormat.format(entry.debit)
                                    : '-',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: entry.debit > 0
                                      ? const Color(0xFFDC2626)
                                      : (isDark
                                            ? Colors.grey.shade700
                                            : Colors.grey.shade400),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Col 4: Credit
                        Expanded(
                          flex: 7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 7,
                            ),
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                entry.credit > 0
                                    ? _currencyFormat.format(entry.credit)
                                    : '-',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: entry.credit > 0
                                      ? const Color(0xFF16A34A)
                                      : (isDark
                                            ? Colors.grey.shade700
                                            : Colors.grey.shade400),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Excel Bottom Total Row (TOTAL, Debit Total, Credit Total - No balance column in table)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                border: Border(
                  top: BorderSide(color: gridColor, width: 1.5),
                  bottom: BorderSide(
                    color: isDark
                        ? const Color(0xFF475569)
                        : Colors.grey.shade700,
                    width: 2.2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 23, // 8 + 15
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: gridColor, width: 0.8),
                        ),
                      ),
                      child: Text(
                        _isAmharic ? 'ጠቅላላ ድምር (ብር)' : 'TOTAL (ETB)',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: gridColor, width: 0.8),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _currencyFormat.format(st.totals.totalDebit),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _currencyFormat.format(st.totals.totalCredit),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            color: Color(0xFF16A34A),
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
    );
  }

  /// Totals Card matching the Excel reference photo
  Widget _buildExcelTotalsCard(AccountStatement st) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isStock = st.accountType == 'stock';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isStock
                    ? (_isAmharic ? 'ጠቅላላ ገቢ ዕቃ፦' : 'Total Stock In:')
                    : (_isAmharic ? 'ጠቅላላ ተቀባይ፦' : 'Total Debit:'),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
              Text(
                'ETB ${_currencyFormat.format(st.totals.totalDebit)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isStock
                    ? (_isAmharic ? 'ጠቅላላ ወጪ ዕቃ፦' : 'Total Stock Out:')
                    : (_isAmharic
                          ? 'ጠቅላላ ተከፋይ (ክፍያዎች)፦'
                          : 'Total Credit (Payments):'),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
              Text(
                'ETB ${_currencyFormat.format(st.totals.totalCredit)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF16A34A),
                ),
              ),
            ],
          ),
          Divider(height: 16, thickness: 1, color: theme.dividerColor),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isStock
                    ? (_isAmharic
                          ? 'የመደብር እቃዎች ዋጋ፦'
                          : 'INVENTORY ON HAND VALUE:')
                    : (_isAmharic ? 'የተጣራ ቀሪ ሂሳብ፦' : 'OUTSTANDING BALANCE:'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                'ETB ${_currencyFormat.format(st.totals.outstanding)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: st.totals.outstanding > 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
