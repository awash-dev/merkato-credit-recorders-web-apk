// ignore_for_file: deprecated_member_use
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

Future<void> autoShareStatementToTelegramPlatform({
  required Uint8List? imageBytes,
  required String filename,
  required String messageText,
  String? title,
}) async {
  // 1. Copy image directly to browser clipboard if bytes are available
  if (imageBytes != null && imageBytes.isNotEmpty) {
    try {
      final blob = html.Blob([imageBytes], 'image/png');
      final item = js.JsObject(js.context['ClipboardItem'], [
        js.JsObject.jsify({'image/png': blob})
      ]);
      final clipboard = js.context['navigator']?['clipboard'];
      clipboard?.callMethod('write', [js.JsArray.from([item])]);
    } catch (e) {
      debugPrint('Web clipboard image write error: $e');
    }
  }

  // 2. Automatically download statement image file
  if (imageBytes != null && imageBytes.isNotEmpty) {
    try {
      final blob = html.Blob([imageBytes], 'image/png');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      debugPrint('Direct image download error: $e');
    }
  }

  // 3. Auto-detect and open Telegram app directly
  final encoded = Uri.encodeComponent(messageText);

  // Directly launch installed Telegram Desktop app via custom scheme
  try {
    final tgAppAnchor = html.AnchorElement(href: 'tg://msg?text=$encoded')
      ..style.display = 'none';
    html.document.body?.children.add(tgAppAnchor);
    tgAppAnchor.click();
    html.document.body?.children.remove(tgAppAnchor);
  } catch (e) {
    debugPrint('tg:// launch attempt error: $e');
  }

  // Also open Telegram share URL as universal web/app handler
  final telegramUrl = 'https://t.me/share/url?text=$encoded';
  html.window.open(telegramUrl, '_blank');
}
