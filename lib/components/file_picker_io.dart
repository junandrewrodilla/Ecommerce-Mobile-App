import 'dart:io'; // File class
import 'package:image_picker/image_picker.dart';

// Function to return a file for mobile platforms
Future<File> pickImage(XFile pickedFile) async {
  return File(pickedFile.path);
}
