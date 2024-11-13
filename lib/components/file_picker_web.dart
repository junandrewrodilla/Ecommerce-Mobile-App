import 'dart:typed_data'; // Uint8List for web
import 'package:image_picker/image_picker.dart';

// Function to return image bytes for web platforms
Future<Uint8List> pickImage(XFile pickedFile) async {
  return await pickedFile.readAsBytes();
}
