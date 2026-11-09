import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

Future<Uint8List?> pickImageBytesFromDevice() async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      return await picked.readAsBytes();
    }
  } catch (e) {
    // Return null on cancel or error
  }
  return null;
}

