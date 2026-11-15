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

  // Open Telegram share URL
  final telegramUrl =
      Uri.parse('https://t.me/share/url?text=${Uri.encodeComponent(messageText)}');
  try {
    if (await canLaunchUrl(telegramUrl)) {
      await launchUrl(telegramUrl, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(telegramUrl, mode: LaunchMode.platformDefault);
    }
  } catch (e) {
    debugPrint('IO Telegram launch error: $e');
  }
}
