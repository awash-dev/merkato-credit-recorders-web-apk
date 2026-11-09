import 'dart:typed_data';

import 'file_image_picker_stub.dart'
    if (dart.library.html) 'file_image_picker_web.dart'
    if (dart.library.io) 'file_image_picker_io.dart';

Future<Uint8List?> pickImageBytes() => pickImageBytesFromDevice();

