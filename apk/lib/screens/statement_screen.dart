import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/statement.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/app_settings_service.dart';
import '../services/ethiopian_calendar.dart';
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

  @override
  void initState() {
    super.initState();
    _loadStatement();
  }

  /// Converts a Gregorian YYYY-MM-DD or standard date string into an authentic Ethiopian calendar date
  String _formatEthiopianDate(String rawDate) {
    if (rawDate.isEmpty) return '';
    try {
      for (final m in EthiopianCalendar.monthsAm) {
        if (m.isNotEmpty && rawDate.contains(m)) return rawDate;
      }
      for (final m in EthiopianCalendar.monthsEn) {
        if (m.isNotEmpty && rawDate.contains(m)) return rawDate;
      }

      final parts = rawDate.split(RegExp(r'[-/]'));
      if (parts.length == 3) {
        final p0 = int.tryParse(parts[0]);
        final p1 = int.tryParse(parts[1]);
        final p2 = int.tryParse(parts[2]);
        if (p0 != null && p1 != null && p2 != null) {
          if (p0 > 1900 && p0 <= 2100) {
            final eth = EthiopianCalendar.toEthiopian(p0, p1, p2);
            return EthiopianCalendar.formatDisplay(eth, lang: _isAmharic ? 'am' : 'en');
          }
          if (p2 > 1900 && p2 <= 2100) {
            final eth = EthiopianCalendar.toEthiopian(p2, p1, p0);
            return EthiopianCalendar.formatDisplay(eth, lang: _isAmharic ? 'am' : 'en');
          }
        }
      }

      final dt = DateTime.tryParse(rawDate);
      if (dt != null) {
        final eth = EthiopianCalendar.toEthiopian(dt.year, dt.month, dt.day);
        return EthiopianCalendar.formatDisplay(eth, lang: _isAmharic ? 'am' : 'en');
      }
    } catch (_) {}
    return rawDate;
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

  /// Captures ONLY the table widget as a clean screenshot image and prints or shares it
  Future<void> _captureTableScreenshot({bool share = true}) async {
    try {
      final boundary =
          _tableKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      final pdf = pw.Document();
      final pdfImage = pw.MemoryImage(pngBytes);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
      final pdfBytes = await pdf.save();

      if (share) {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'table-${widget.accountName.replaceAll(' ', '_')}.pdf',
        );
      } else {
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'table-${widget.accountName.replaceAll(' ', '_')}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Screenshot capture: $e')),
        );
      }
    }
  }

  /// Opens social media sharing sheet for PDF, Table Screenshot, or Text
  Future<void> _shareStatement() async {
    if (_statement == null) return;
    final st = _statement!;

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
              Text(
                _isAmharic ? 'መግለጫውን አጋራ' : 'Share Statement',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFDC2626)),
                title: Text(_isAmharic ? 'ሙሉ ፒዲኤፍ አጋራ' : 'Share Full PDF Document'),
                subtitle: Text(
                  _isAmharic
                      ? 'በዋትስአፕ፣ ቴሌግራም ወይም ኢሜል'
                      : 'Via WhatsApp, Telegram, or Email',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _printOrExportPdf(shareOnly: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF2563EB)),
                title: Text(
                  _isAmharic
                      ? 'የሠንጠረዥ ስክሪንሾት አጋራ'
                      : 'Share Table Screenshot (Only Table)',
                ),
                subtitle: Text(
                  _isAmharic
                      ? 'የኤክሴል ሠንጠረዥ ምስል ብቻ'
                      : 'Clean image snapshot of the Excel table',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _captureTableScreenshot(share: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF16A34A)),
                title: Text(_isAmharic ? 'የጽሑፍ ማጠቃለያ አጋራ' : 'Share Text Summary'),
                subtitle: Text(
                  _isAmharic
                      ? 'ቀሪ ሂሳብ እና ጠቅላላ ድምር'
                      : 'Quick balance & totals summary',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final pdf = pw.Document();
                  pdf.addPage(
                    pw.Page(
                      pageFormat: PdfPageFormat.a4,
                      build: (pw.Context context) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.all(30),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                AppSettingsService.appTitleNotifier.value,
                                style: pw.TextStyle(
                                  fontSize: 20,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 10),
                              pw.Text(
                                'Account: ${st.accountName}',
                                style: const pw.TextStyle(fontSize: 14),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                'Total Debit: ETB ${_currencyFormat.format(st.totals.totalDebit)}',
                              ),
                              pw.Text(
                                'Total Credit: ETB ${_currencyFormat.format(st.totals.totalCredit)}',
                              ),
                              pw.SizedBox(height: 8),
                              pw.Text(
                                'Outstanding Balance: ETB ${_currencyFormat.format(st.totals.outstanding)}',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 16,
                                  color: PdfColors.red900,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                  await Printing.sharePdf(
                    bytes: await pdf.save(),
                    filename: 'summary-${st.accountName.replaceAll(' ', '_')}.pdf',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Opens an interactive Excel-style modal row editor upon clicking any statement row
  Future<void> _openExcelRowEditor(StatementEntry entry) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final descController = TextEditingController(text: entry.description);
    final qtyController = TextEditingController(
      text: entry.quantity > 0 ? entry.quantity.toStringAsFixed(0) : '',
    );
    final priceController = TextEditingController(
      text: entry.unitPrice > 0 ? entry.unitPrice.toStringAsFixed(2) : '',
    );
    final dateController = TextEditingController(text: entry.date);
    final bankController = TextEditingController(text: entry.bank ?? '');
    final notesController = TextEditingController(text: entry.notes ?? '');

    double calcSubtotal() {
      final q = double.tryParse(qtyController.text.trim()) ?? 0;
      final p = double.tryParse(priceController.text.trim()) ?? 0;
      return q * p;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final cardColor = isDark ? const Color(0xFF1B2234) : Colors.white;
            final subtotal = calcSubtotal();

            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: SingleChildScrollView(
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.table_chart_outlined,
                              color: Color(0xFF2563EB),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isAmharic ? 'የረድፍ ኤክሴል ማስተካከያ' : 'Excel Row Editor',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: InputDecoration(
                        labelText: _isAmharic ? 'የዕቃው አይነት / ስም' : 'Item Description',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dateController,
                      decoration: InputDecoration(
                        labelText: _isAmharic ? 'ቀን' : 'Date',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today, size: 18),
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: now,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              dateController.text =
                                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                              setModalState(() {});
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: _isAmharic ? 'ብዛት (Pcs)' : 'Quantity (Pcs)',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: _isAmharic ? 'ዋጋ (ETB)' : 'Price (ETB)',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF242C40) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isAmharic ? 'ድምር ዋጋ፦' : 'Calculated Total:',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Text(
                            'ETB ${_currencyFormat.format(subtotal > 0 ? subtotal : (entry.debit > 0 ? entry.debit : entry.credit))}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bankController,
                      decoration: InputDecoration(
                        labelText: _isAmharic ? 'ባንክ / የክፍያ ዘዴ' : 'Bank / Method',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: _isAmharic ? 'ማስታወሻ' : 'Notes / Reference',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(
                        _isAmharic ? 'ለውጦችን መዝግብ' : 'Save Changes',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        if (entry.recordId == null || entry.id == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cannot edit: Entry not linked to an editable record.'),
                            ),
                          );
                          Navigator.pop(ctx);
                          return;
                        }
                        try {
                          final q = double.tryParse(qtyController.text.trim()) ?? 0;
                          final p = double.tryParse(priceController.text.trim()) ?? 0;
                          await ApiService.updateStatementEntry(
                            recordId: entry.recordId!,
                            itemId: entry.id!,
                            description: descController.text.trim(),
                            quantity: q,
                            unitPrice: p,
                            date: dateController.text.trim(),
                            bank: bankController.text.trim().isEmpty ? null : bankController.text.trim(),
                            notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_isAmharic ? 'ረድፉ በተሳካ ሁኔታ ተስተካክሏል' : 'Row updated successfully!'),
                                backgroundColor: const Color(0xFF16A34A),
                              ),
                            );
                            _loadStatement();
                          }
                        } catch (err) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _printOrExportPdf({bool shareOnly = false}) async {
    if (_statement == null) return;
    final st = _statement!;

    final pdf = pw.Document();
    final logoBytes = AppSettingsService.getLogoBytes();
    final customTitle = AppSettingsService.appTitleNotifier.value;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return [
            // Header with dynamic App Title & dynamic Logo
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logoBytes != null) ...[
                      pw.Container(
                        width: 36,
                        height: 36,
                        margin: const pw.EdgeInsets.only(right: 10),
                        child: pw.ClipRRect(
                          horizontalRadius: 6,
                          verticalRadius: 6,
                          child: pw.Image(pw.MemoryImage(logoBytes)),
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
                              ? 'Account Statement'
                              : '${st.storeName} - Account Statement',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Account: ${st.accountName} (${st.accountType.toUpperCase()})',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
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
                      'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'Currency: ETB',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 8),

            // Excel-style Statement Table (without Balance column, x instead of @, Ethiopian date)
            pw.TableHelper.fromTextArray(
              headers: [
                'Date',
                'Item',
                'Qty x Price',
                'Debit (+)',
                'Credit (-)',
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
              data: st.entries.map((entry) {
                final qtyPrice = (entry.quantity > 0 && entry.unitPrice > 0)
                    ? '${entry.quantity.toInt()} pcs x ${_currencyFormat.format(entry.unitPrice)}'
                    : '-';
                return [
                  _formatEthiopianDate(entry.date),
                  entry.description +
                      (entry.bank != null ? ' [${entry.bank}]' : ''),
                  qtyPrice,
                  entry.debit > 0 ? _currencyFormat.format(entry.debit) : '-',
                  entry.credit > 0 ? _currencyFormat.format(entry.credit) : '-',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 12),

            // Statement Totals
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(4),
                color: PdfColors.grey100,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTALS (${st.entries.length} entries)',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  pw.Row(
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Total Debit: ETB ${_currencyFormat.format(st.totals.totalDebit)}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.Text(
                            'Total Credit: ETB ${_currencyFormat.format(st.totals.totalCredit)}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                      pw.SizedBox(width: 18),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'OUTSTANDING BALANCE',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'ETB ${_currencyFormat.format(st.totals.outstanding)}',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red900,
                            ),
                          ),
                        ],
                      ),
                    ],
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
            // 1. Capture Table Screenshot (Only Tables)
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined, size: 20),
              tooltip: _isAmharic
                  ? 'የሠንጠረዥ ስክሪንሾት ውሰድ'
                  : 'Capture Table Screenshot',
              onPressed: () => _captureTableScreenshot(share: false),
            ),

            // 2. Export / Print PDF Statement
            IconButton(
              icon: const Icon(Icons.print_outlined, size: 20),
              tooltip: _isAmharic ? 'መግለጫ አትም / ፒዲኤፍ' : 'Print Statement',
              onPressed: () => _printOrExportPdf(shareOnly: false),
            ),

            // 3. Share to Social Media (WhatsApp, Telegram, etc.)
            IconButton(
              icon: const Icon(Icons.share_outlined, size: 20),
              tooltip: _isAmharic
                  ? 'በማህበራዊ ሚዲያ አጋራ'
                  : 'Share to Social Media',
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

  Widget _buildStatementContent(AccountStatement st) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCustomer = st.accountType == 'customer';
    final isDelala = st.accountType == 'delala';
    final isStock = st.accountType == 'stock';

    final formulaText = isStock
        ? (_isAmharic
              ? 'በመደብር ያለው = ገቢ (+) - ወጪ (-)'
              : 'Store On Hand = Stock In (+) - Stock Out (-)')
        : isCustomer
        ? (_isAmharic
              ? 'የደንበኛ ቀሪ = ጠቅላላ ተቀባይ - ጠቅላላ ተከፋይ'
              : 'Customer Balance = Total Debit - Total Credit')
        : isDelala
        ? (_isAmharic
              ? 'የደላላ ቀሪ = የወሰደው - የመለሰው'
              : 'Delala Balance = Commission Earned - Paid')
        : (_isAmharic
              ? 'የአቅራቢ ቀሪ = ጠቅላላ ተከፋይ - ጠቅላላ ተቀባይ'
              : 'Supplier Balance = Total Credit - Total Debit');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Account Summary Card with dynamic App Logo
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppSettingsService.buildLogoWidget(size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.accountName,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                          height: 1.25,
                        ),
                        softWrap: true,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(st.totals.outstanding),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: st.totals.outstanding > 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const SizedBox(height: 1),
                const SizedBox(height: 2),
                Text(
                  formulaText,
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Authentic Excel Ledger Table (Zero Horizontal Scrolling, Authentic Gridlines)
          // Wrapped in RepaintBoundary for single-table high-res screenshot capture
          RepaintBoundary(
            key: _tableKey,
            child: _buildMobileExcelTable(st),
          ),
          const SizedBox(height: 12),

          // Excel Totals Footer Card
          _buildExcelTotalsCard(st),
        ],
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
                final isEven = index % 2 == 0;

                final rowBg = isEven
                    ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                    : (isDark
                          ? const Color(0xFF18181B)
                          : const Color(0xFFF8FAFC));

                return InkWell(
                  onTap: () => _openExcelRowEditor(entry),
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
