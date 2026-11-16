import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

const MethodChannel _channel =
    MethodChannel('com.eyobaledger.apk/telegram_share');

Future<void> autoShareStatementToTelegramPlatform({
  required Uint8List? imageBytes,
  required String filename,
  required String messageText,
  String? title,
}) async {
  String? savedFilePath;

  // 1. Save image to temporary directory so Telegram can access it via FileProvider
  if (imageBytes != null && imageBytes.isNotEmpty) {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(imageBytes);
      savedFilePath = file.path;
    } catch (e) {
      debugPrint('IO image write error: $e');
    }
  }

  // 2. On Android, deeply share image to Telegram (Intent.ACTION_SEND with FileProvider)
  // This opens Telegram directly to its chat/contact picker with the image attached
  // exactly like sharing an image from Android Gallery to Telegram!
  if (Platform.isAndroid && savedFilePath != null) {
    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'shareImageToTelegram',
        {
          'filePath': savedFilePath,
          'text': messageText,
        },
      );
      if (success == true) {
        return;
      }
    } catch (e) {
      debugPrint('Native Android Telegram share error: $e');
    }
  }

  // 3. Fallback: try native Telegram custom schemes to auto-detect and open the Telegram app directly
  final encoded = Uri.encodeComponent(messageText);
  final directTelegramUris = [
    Uri.parse('tg://msg?text=$encoded'),
    Uri.parse('tg://share/url?text=$encoded'),
    Uri.parse('tg://resolve?domain=telegram&post=$encoded'),
  ];

  bool openedApp = false;
  for (final uri in directTelegramUris) {
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) {
        openedApp = true;
        break;
      }
    } catch (e) {
      debugPrint('Direct tg:// launch attempt failed: $e');
    }
  }

  // 4. Final fallback to https://t.me/share/url
  if (!openedApp) {
    final webTelegramUrl = Uri.parse('https://t.me/share/url?text=$encoded');
    try {
      await launchUrl(webTelegramUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(webTelegramUrl, mode: LaunchMode.platformDefault);
      } catch (e) {
        debugPrint('IO Telegram fallback launch error: $e');
      }
    }
  }
}
