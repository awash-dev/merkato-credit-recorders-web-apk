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
import '../services/telegram_share.dart';
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

  /// Automatically captures screenshot, auto-copies to clipboard, and auto-opens Telegram so user only selects recipient
  Future<void> _sendToTelegram() async {
    if (_statement == null) return;
    final st = _statement!;
    final customTitle = AppSettingsService.appTitleNotifier.value;
    final displayName = st.storeName.isNotEmpty
        ? st.storeName
        : (customTitle.toLowerCase().contains('merkato') ||
                customTitle.toLowerCase().contains('መርካቶ')
            ? (_isAmharic ? 'መደብር' : 'Store')
            : customTitle);

    final dateDisplay = _isAmharic
        ? EthiopianCalendar.formatDisplay(EthiopianCalendar.now(), lang: 'am')
        : EthiopianCalendar.formatDisplay(EthiopianCalendar.now(), lang: 'en');
    final timeDisplay = DateFormat('HH:mm').format(DateTime.now());

    // 1. Automatically capture high-resolution complete statement screenshot immediately
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

    // 2. Build full formatted statement summary
    final buffer = StringBuffer();
    buffer.writeln('🏪 $displayName');
    buffer.writeln('${_isAmharic ? "የሂሳብ ስም" : "Account"}: ${st.accountName} (${st.accountType.toUpperCase()})');
    buffer.writeln('${_isAmharic ? "ቀን" : "Date"}: $dateDisplay ($timeDisplay)');
    buffer.writeln('----------------------------------------');
    buffer.writeln('${_isAmharic ? "የዕቃዎች ዝርዝር" : "ITEMS"}:');

    for (final entry in st.entries) {
      final qtyStr = entry.quantity % 1 == 0
          ? entry.quantity.toInt().toString()
          : entry.quantity.toString();
      final priceStr = _currencyFormat.format(entry.unitPrice);
      if (entry.debit > 0) {
        buffer.writeln('• ${entry.description}');
        buffer.writeln('  $qtyStr x $priceStr = ${_currencyFormat.format(entry.debit)} ETB');
      } else if (entry.credit > 0) {
        final bankSuffix = entry.bank != null ? ' [${entry.bank}]' : '';
        buffer.writeln('• ${entry.description}$bankSuffix');
        buffer.writeln('  ${_currencyFormat.format(entry.credit)} ETB (${_isAmharic ? "ገቢ" : "Payment"})');
      } else {
        buffer.writeln('• ${entry.description}');
      }
    }

    buffer.writeln('----------------------------------------');
    buffer.writeln('${_isAmharic ? "ጠቅላላ ሂሳብ" : "Total Amount"}: ETB ${_currencyFormat.format(st.totals.totalDebit)}');
    buffer.writeln('${_isAmharic ? "ጠቅላላ ገቢ (ክፍያ)" : "Total Payment (ገቢ)"}: ETB ${_currencyFormat.format(st.totals.totalCredit)}');
    buffer.writeln('${_isAmharic ? "የተጣራ ቀሪ ሂሳብ" : "OUTSTANDING BALANCE"}: ETB ${_currencyFormat.format(st.totals.outstanding)}');

    final text = buffer.toString();

    // 3. Automatically copy text to clipboard
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {}

    final cleanName = widget.accountName.replaceAll(' ', '_');
    final filename = 'statement-$cleanName.png';

    // 4. Automatically auto-copy screenshot, auto-share image and open Telegram (no option dialogs)
    await autoShareStatementToTelegram(
      imageBytes: tableImageBytes,
      filename: filename,
      messageText: text,
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
                      ? 'ስክሪንሾት እና መረጃው ተገልብጠዋል! ቴሌግራም ላይ ተጠቃሚውን ብቻ ይምረጡ'
                      : 'Screenshot & info copied! Select recipient in Telegram...',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF24A1DE),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

    Uint8List? effectiveLogoBytes = AppSettingsService.getLogoBytes();
    if (effectiveLogoBytes == null) {
      try {
        final byteData = await rootBundle.load('assets/app_icon.png');
        effectiveLogoBytes = byteData.buffer.asUint8List();
      } catch (_) {}
    }

    final customTitle = AppSettingsService.appTitleNotifier.value;
    final displayName = st.storeName.isNotEmpty
        ? st.storeName
        : (customTitle.toLowerCase().contains('merkato') ||
                customTitle.toLowerCase().contains('መርካቶ')
            ? (_isAmharic ? 'መደብር' : 'Store')
            : customTitle);

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

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        theme: themeData,
        build: (pw.Context context) {
          return [
            // Exact Replica of In-App Card Container
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(
                  color: const PdfColor.fromInt(0xFFCBD5E1),
                  width: 1.2,
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // 1. Top Header Row (Logo + Store Name + Date & Currency Pill)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          if (effectiveLogoBytes != null)
                            pw.Container(
                              width: 38,
                              height: 38,
                              margin: const pw.EdgeInsets.only(right: 8),
                              decoration: pw.BoxDecoration(
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.ClipRRect(
                                horizontalRadius: 6,
                                verticalRadius: 6,
                                child: pw.Image(
                                  pw.MemoryImage(effectiveLogoBytes),
                                  fit: pw.BoxFit.cover,
                                ),
                              ),
                            ),
                          pw.Text(
                            displayName,
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            '$dateDisplay ($timeDisplay)',
                            style: const pw.TextStyle(
                              fontSize: 9.5,
                              color: PdfColor.fromInt(0xFF475569),
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: const PdfColor.fromInt(0xFFF1F5F9),
                              borderRadius: pw.BorderRadius.circular(4),
                              border: pw.Border.all(
                                color: const PdfColor.fromInt(0xFFCBD5E1),
                                width: 0.8,
                              ),
                            ),
                            child: pw.Text(
                              'Currency: ETB',
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),

                  // 2. Blue Account Banner
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFEFF6FF),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '${_isAmharic ? 'የሂሳብ ስም' : 'Account'}: ${st.accountName}',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFF2563EB),
                          ),
                        ),
                        pw.Text(
                          st.accountType.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),

                  // 3. Exactly 4-Column Table Matching In-App Preview
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(7),
                      border: pw.Border.all(
                        color: const PdfColor.fromInt(0xFFCBD5E1),
                        width: 1.2,
                      ),
                    ),
                    child: pw.ClipRRect(
                      horizontalRadius: 6,
                      verticalRadius: 6,
                      child: pw.Column(
                        children: [
                          // Table Header
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6),
                            color: const PdfColor.fromInt(0xFFF1F5F9),
                            child: pw.Row(
                              children: [
                                pw.Expanded(
                                  flex: 8,
                                  child: pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                                    child: pw.Text(
                                      _isAmharic ? 'ቀን' : 'Date',
                                      style: pw.TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: pw.FontWeight.bold,
                                        color: const PdfColor.fromInt(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                ),
                                pw.Expanded(
                                  flex: 15,
                                  child: pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                                    child: pw.Text(
                                      _isAmharic ? 'ዕቃ' : 'Item',
                                      style: pw.TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: pw.FontWeight.bold,
                                        color: const PdfColor.fromInt(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                ),
                                pw.Expanded(
                                  flex: 7,
                                  child: pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                                    child: pw.Text(
                                      _isAmharic ? 'ጠቅላላ (+)' : 'Total (+)',
                                      textAlign: pw.TextAlign.right,
                                      style: pw.TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: pw.FontWeight.bold,
                                        color: const PdfColor.fromInt(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                ),
                                pw.Expanded(
                                  flex: 7,
                                  child: pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                                    child: pw.Text(
                                      _isAmharic ? 'ገቢ (-)' : 'Payment (-)',
                                      textAlign: pw.TextAlign.right,
                                      style: pw.TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: pw.FontWeight.bold,
                                        color: const PdfColor.fromInt(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.Divider(height: 1, thickness: 1, color: const PdfColor.fromInt(0xFFCBD5E1)),

                          // Table Rows
                          ...st.entries.asMap().entries.map((itemMap) {
                            final idx = itemMap.key;
                            final entry = itemMap.value;
                            final isEven = idx % 2 == 0;
                            final rowBg = isEven ? PdfColors.white : const PdfColor.fromInt(0xFFF8FAFC);
                            final qtyStr = entry.quantity % 1 == 0
                                ? entry.quantity.toInt().toString()
                                : entry.quantity.toString();

                            return pw.Container(
                              color: rowBg,
                              padding: const pw.EdgeInsets.symmetric(vertical: 6),
                              child: pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.center,
                                children: [
                                  // Col 1: Date
                                  pw.Expanded(
                                    flex: 8,
                                    child: pw.Padding(
                                      padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                                      child: pw.Text(
                                        _formatEthiopianDate(entry.date),
                                        style: const pw.TextStyle(
                                          fontSize: 8.5,
                                          color: PdfColor.fromInt(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Col 2: Item Description + Qty x Price (NO "pcs"!)
                                  pw.Expanded(
                                    flex: 15,
                                    child: pw.Padding(
                                      padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                                      child: pw.Column(
                                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                                        children: [
                                          pw.Text(
                                            entry.description,
                                            style: pw.TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: pw.FontWeight.bold,
                                              color: const PdfColor.fromInt(0xFF1E293B),
                                            ),
                                          ),
                                          if (entry.quantity > 0 && entry.unitPrice > 0)
                                            pw.Padding(
                                              padding: const pw.EdgeInsets.only(top: 2),
                                              child: pw.Text(
                                                '$qtyStr x ${_currencyFormat.format(entry.unitPrice)}',
                                                style: const pw.TextStyle(
                                                  fontSize: 8,
                                                  color: PdfColor.fromInt(0xFF64748B),
                                                ),
                                              ),
                                            )
                                          else if (entry.bank != null)
                                            pw.Padding(
                                              padding: const pw.EdgeInsets.only(top: 2),
                                              child: pw.Text(
                                                '[${entry.bank}]',
                                                style: pw.TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: pw.FontWeight.bold,
                                                  color: const PdfColor.fromInt(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Col 3: Total (+)
                                  pw.Expanded(
                                    flex: 7,
                                    child: pw.Padding(
                                      padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                                      child: pw.Text(
                                        entry.debit > 0 ? _currencyFormat.format(entry.debit) : '-',
                                        textAlign: pw.TextAlign.right,
                                        style: pw.TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: pw.FontWeight.bold,
                                          color: entry.debit > 0
                                              ? const PdfColor.fromInt(0xFFDC2626)
                                              : const PdfColor.fromInt(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Col 4: Payment (-)
                                  pw.Expanded(
                                    flex: 7,
                                    child: pw.Padding(
                                      padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                                      child: pw.Text(
                                        entry.credit > 0 ? _currencyFormat.format(entry.credit) : '-',
                                        textAlign: pw.TextAlign.right,
                                        style: pw.TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: pw.FontWeight.bold,
                                          color: entry.credit > 0
                                              ? const PdfColor.fromInt(0xFF16A34A)
                                              : const PdfColor.fromInt(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          pw.Divider(height: 1, thickness: 1, color: const PdfColor.fromInt(0xFFCBD5E1)),

                          // Total Footer Row
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 7),
                            color: const PdfColor.fromInt(0xFFF1F5F9),
                            child: pw.Row(
                              children: [
                                pw.Expanded(
                                  flex: 23,
                                  child: pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                                    child: pw.Text(
                                      _isAmharic ? 'ጠቅላላ ድምር (ብር)' : 'TOTAL (ETB)',
                                      style: pw.TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: pw.FontWeight.bold,
                                        color: const PdfColor.fromInt(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                ),
                                pw.Expanded(
                                  flex: 7,
                                  child: pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                                    child: pw.Text(
                                      _currencyFormat.format(st.totals.totalDebit),
                                      textAlign: pw.TextAlign.right,
                                      style: pw.TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: pw.FontWeight.bold,
                                        color: const PdfColor.fromInt(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                ),
                                pw.Expanded(
                                  flex: 7,
                                  child: pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                                    child: pw.Text(
                                      _currencyFormat.format(st.totals.totalCredit),
                                      textAlign: pw.TextAlign.right,
                                      style: pw.TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: pw.FontWeight.bold,
                                        color: const PdfColor.fromInt(0xFF16A34A),
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
                  ),
                  pw.SizedBox(height: 10),

                  // 4. Totals Summary Card
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(
                        color: const PdfColor.fromInt(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              _isAmharic ? 'ጠቅላላ ሂሳብ፦' : 'Total Amount:',
                              style: const pw.TextStyle(
                                fontSize: 10,
                                color: PdfColor.fromInt(0xFF64748B),
                              ),
                            ),
                            pw.Text(
                              'ETB ${_currencyFormat.format(st.totals.totalDebit)}',
                              style: pw.TextStyle(
                                fontSize: 10.5,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              _isAmharic ? 'ጠቅላላ ገቢ (ክፍያ)፦' : 'Total Payment (ገቢ):',
                              style: const pw.TextStyle(
                                fontSize: 10,
                                color: PdfColor.fromInt(0xFF64748B),
                              ),
                            ),
                            pw.Text(
                              'ETB ${_currencyFormat.format(st.totals.totalCredit)}',
                              style: pw.TextStyle(
                                fontSize: 10.5,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                        pw.Divider(height: 14, thickness: 0.8, color: const PdfColor.fromInt(0xFFE2E8F0)),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              _isAmharic ? 'የተጣራ ቀሪ ሂሳብ፦' : 'OUTSTANDING BALANCE:',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF1E293B),
                              ),
                            ),
                            pw.Text(
                              'ETB ${_currencyFormat.format(st.totals.outstanding)}',
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                color: st.totals.outstanding > 0
                                    ? const PdfColor.fromInt(0xFFDC2626)
                                    : const PdfColor.fromInt(0xFF16A34A),
                              ),
                            ),
                          ],
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
              icon: const Icon(Icons.print_outlined, size: 21),
              tooltip: _isAmharic ? 'መግለጫ አትም / ፒዲኤፍ' : 'Print / Export PDF',
              onPressed: () => _printOrExportPdf(shareOnly: false),
            ),

            // 2. Telegram Send Button (Replaces Share button, directly sends statement info to Telegram)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const TelegramIconWidget(size: 24),
                tooltip: _isAmharic
                    ? 'መረጃውን በቴሌግራም ላክ'
                    : 'Send Statement Info to Telegram',
                onPressed: _sendToTelegram,
              ),
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
    final dateDisplay = _isAmharic
        ? EthiopianCalendar.formatDisplay(EthiopianCalendar.now(), lang: 'am')
        : EthiopianCalendar.formatDisplay(EthiopianCalendar.now(), lang: 'en');
    final timeDisplay = DateFormat('HH:mm').format(DateTime.now());

    return ValueListenableBuilder<String>(
      valueListenable: AppSettingsService.appTitleNotifier,
      builder: (context, customTitle, _) {
        final displayName = st.storeName.isNotEmpty
            ? st.storeName
            : (customTitle.toLowerCase().contains('merkato') ||
                    customTitle.toLowerCase().contains('መርካቶ')
                ? (_isAmharic ? 'መደብር' : 'Store')
                : customTitle);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final success =
                            await AppSettingsService.pickAndSaveLogo();
                        if (success && mounted) {
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _isAmharic
                                    ? 'የመደብር ሎጎ በተሳካ ሁኔታ ተቀይሯል!'
                                    : 'Store logo updated successfully!',
                              ),
                              backgroundColor: const Color(0xFF16A34A),
                            ),
                          );
                        }
                      },
                      child: Tooltip(
                        message: _isAmharic
                            ? 'የመደብሩን ሎጎ ለመቀየር ይንኩ'
                            : 'Tap to change store logo image',
                        child: AppSettingsService.buildLogoWidget(size: 36),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
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
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFCBD5E1),
                          width: 0.8,
                        ),
                      ),
                      child: const Text(
                        'Currency: ETB',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
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
      },
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
                            : (_isAmharic ? 'ጠቅላላ (+)' : 'Total (+)'),
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
                            : (_isAmharic ? 'ገቢ (-)' : 'Payment (-)'),
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
                                      '${entry.quantity % 1 == 0 ? entry.quantity.toInt() : entry.quantity} x ${_currencyFormat.format(entry.unitPrice)}',
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

  /// Totals Card matching the reference design
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
                    : (_isAmharic ? 'ጠቅላላ ሂሳብ፦' : 'Total Amount:'),
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
                          ? 'ጠቅላላ ገቢ (ክፍያ)፦'
                          : 'Total Payment (ገቢ):'),
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

class TelegramIconWidget extends StatelessWidget {
  final double size;
  const TelegramIconWidget({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF24A1DE), // Telegram brand blue
        shape: BoxShape.circle,
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.60, size * 0.60),
          painter: _TelegramPlanePainter(),
        ),
      ),
    );
  }
}

class _TelegramPlanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(w * 0.12, h * 0.48);
    path.lineTo(w * 0.92, h * 0.14);
    path.lineTo(w * 0.74, h * 0.88);
    path.lineTo(w * 0.48, h * 0.68);
    path.lineTo(w * 0.38, h * 0.78);
    path.lineTo(w * 0.36, h * 0.60);
    path.lineTo(w * 0.76, h * 0.28);
    path.lineTo(w * 0.28, h * 0.54);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
