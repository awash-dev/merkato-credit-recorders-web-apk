import 'dart:typed_data';

Future<bool> shareOrSaveImageBytesFromDevice(
  Uint8List bytes,
  String filename, {
  String? title,
}) async {
  throw UnsupportedError('Cannot share image on this platform.');
}

