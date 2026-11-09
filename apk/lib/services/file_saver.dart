import 'dart:typed_data';

import 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_io.dart';

Future<bool> shareOrSaveImageBytes(
  Uint8List bytes,
  String filename, {
  String? title,
}) =>
    shareOrSaveImageBytesFromDevice(bytes, filename, title: title);

