import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> autoShareStatementToTelegramPlatform({
  required Uint8List? imageBytes,
  required String filename,
  required String messageText,
  String? title,
}) async {
  // Save image to temporary directory
  if (imageBytes != null && imageBytes.isNotEmpty) {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(imageBytes);
    } catch (e) {
      debugPrint('IO image write error: $e');
    }
  }

  // 1. Try native Telegram custom schemes to auto-detect and open the Telegram app directly
  final encoded = Uri.encodeComponent(messageText);
  final directTelegramUris = [
    Uri.parse('tg://msg?text=$encoded'),
    Uri.parse('tg://share/url?text=$encoded'),
  ];

  bool openedApp = false;
  for (final uri in directTelegramUris) {
    try {
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) {
          openedApp = true;
          break;
        }
      }
    } catch (e) {
      debugPrint('Direct tg:// launch check error: $e');
    }
  }

  // 2. If native tg:// scheme did not open the app, fall back to https://t.me/share/url
  if (!openedApp) {
    final webTelegramUrl = Uri.parse('https://t.me/share/url?text=$encoded');
    try {
      if (await canLaunchUrl(webTelegramUrl)) {
        await launchUrl(webTelegramUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webTelegramUrl, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('IO Telegram launch error: $e');
    }
  }
}
