import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<bool> shareOrSaveImageBytesFromDevice(
  Uint8List bytes,
  String filename, {
  String? title,
}) async {
  try {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes);
    return true;
  } catch (e) {
    return false;
  }
}

