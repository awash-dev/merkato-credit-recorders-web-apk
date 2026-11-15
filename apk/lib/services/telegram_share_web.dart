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

  // 2. Try Web Share API (native share sheet on Chrome / Safari)
  bool sharedDirectly = false;
  if (imageBytes != null && imageBytes.isNotEmpty) {
    try {
      final nav = html.window.navigator;
      final file = html.File([imageBytes], filename, {'type': 'image/png'});
      final shareData = {
        'files': [file],
        'title': title ?? 'Account Statement',
        'text': messageText,
      };
      await nav.share(shareData);
      sharedDirectly = true;
    } catch (e) {
      debugPrint('Web Share API not supported or dismissed: $e');
    }
  }

  // 3. If Web Share was not used (Desktop browser or unsupported), automatically download the image & open Telegram
  if (!sharedDirectly) {
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

    // Automatically open Telegram with pre-filled message
    final telegramUrl =
        'https://t.me/share/url?text=${Uri.encodeComponent(messageText)}';
    html.window.open(telegramUrl, '_blank');
  }
}
