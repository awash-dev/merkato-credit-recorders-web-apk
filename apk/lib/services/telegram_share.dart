import 'dart:typed_data';

import 'telegram_share_stub.dart'
    if (dart.library.html) 'telegram_share_web.dart'
    if (dart.library.io) 'telegram_share_io.dart';

Future<void> autoShareStatementToTelegram({
  required Uint8List? imageBytes,
  required String filename,
  required String messageText,
  String? title,
}) =>
    autoShareStatementToTelegramPlatform(
      imageBytes: imageBytes,
      filename: filename,
      messageText: messageText,
      title: title,
    );

