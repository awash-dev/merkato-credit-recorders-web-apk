// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List?> pickImageBytesFromDevice() async {
  final completer = Completer<Uint8List?>();
  final input = html.FileUploadInputElement()..accept = 'image/*';
  input.click();

  input.onChange.listen((event) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files[0];
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      final res = reader.result;
      if (!completer.isCompleted) {
        if (res is Uint8List) {
          completer.complete(res);
        } else if (res is ByteBuffer) {
          completer.complete(res.asUint8List());
        } else {
          completer.complete(null);
        }
      }
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
    reader.readAsArrayBuffer(file);
  });

  return completer.future;
}
