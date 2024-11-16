import 'dart:io'; // For File class
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // To pick images from gallery or camera
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'; // For image compression

class AddProductDialog extends StatefulWidget {
  final String userId;
  final DatabaseReference databaseRef;
  final FirebaseStorage storage;
  final String sellerName;

  const AddProductDialog({
    super.key,
    required this.userId,
    required this.databaseRef,
    required this.storage,
    required this.sellerName,
  });

  @override
  _AddProductDialogState createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  File? _mainImageFile;
  final List<File> _additionalImageFiles = [];
  final List<String> _categories = [
    'Bags',
    'Necklaces',
    'Shoes',
    'Blankets',
    'Earrings',
    'Baskets ',
    'Clothes',
  ];

  String productName = '';
  String productPrice = '';
  String productDescription = '';
  String productStocks = '';
  String productCategory = 'Shoes';
  String productStory = '';
  String productDetails = '';
  bool _isUploading = false;

  Future<void> _pickMainImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _mainImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickAdditionalImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _additionalImageFiles.add(File(pickedFile.path));
      });
    }
  }

  Future<File?> compressImage(File file,
      {int maxHeight = 1024, int maxWidth = 1024, int quality = 80}) async {
    final filePath = file.absolute.path;
    final lastIndex = filePath.lastIndexOf(RegExp(r'.jp'));
    final splitted = filePath.substring(0, lastIndex);
    final outPath = "${splitted}_out${filePath.substring(lastIndex)}";

    // Compress and resize the image
    var result = await FlutterImageCompress.compressAndGetFile(
      filePath,
      outPath,
      quality: quality, // Maintain a good quality (around 80-88 is standard)
      minHeight: maxHeight, // Resize the image if needed
      minWidth: maxWidth,
    );

    return result != null ? File(result.path) : null;
  }

  Future<String> _uploadMainImage(String productId) async {
    if (_mainImageFile != null) {
      final compressedFile = await compressImage(_mainImageFile!);
      if (compressedFile != null) {
        final storageRef =
            widget.storage.ref().child('product_images/$productId/main');
        final uploadTask = storageRef.putFile(compressedFile);
        return await uploadTask
            .then((taskSnapshot) => taskSnapshot.ref.getDownloadURL());
      }
    }
    return '';
  }

  Future<List<String>> _uploadAdditionalImages(String productId) async {
    if (_additionalImageFiles.isEmpty) return [];

    List<Future<String>> uploadFutures =
        _additionalImageFiles.map((file) async {
      final compressedFile = await compressImage(file);
      if (compressedFile != null) {
        final storageRef = widget.storage.ref().child(
            'product_images/$productId/additional_${_additionalImageFiles.indexOf(file)}');
        return storageRef
            .putFile(compressedFile)
            .then((taskSnapshot) => taskSnapshot.ref.getDownloadURL());
      }
      return '';
    }).toList();

    return await Future.wait(uploadFutures);
  }

  Future<void> _addToPublicShops(String productId, String mainImageUrl,
      List<String> additionalImageUrls) async {
    final publicShopRef =
        FirebaseDatabase.instance.ref().child('shops/public_shops');
    await publicShopRef.child(productId).set({
      'product_id': productId,
      'name': productName,
      'price': productPrice,
      'description': productDescription,
      'stocks': productStocks,
      'category': productCategory,
      'seller_id': widget.userId,
      'seller_name': widget.sellerName,
      'profileImageUrl': mainImageUrl,
      'additionalImages': additionalImageUrls,
      'product_story': productStory,
      'product_details': productDetails,
      'total_sold': 0, // Initialize total_sold to 0
    });
  }

  Future<void> _uploadProduct() async {
    if (productName.isEmpty ||
        productPrice.isEmpty ||
        productDescription.isEmpty ||
        productStocks.isEmpty ||
        productStory.isEmpty ||
        productDetails.isEmpty ||
        _mainImageFile == null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Missing Information'),
            content:
                const Text('Please fill all the fields and pick a main image.'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
              ),
            ],
          );
        },
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    // Show the loading dialog at the center
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text(
                  "This takes a little longer...",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final newProductRef =
          widget.databaseRef.child(widget.userId).child('products').push();
      String productId = newProductRef.key!;

      final mainImageUpload = _uploadMainImage(productId);
      final additionalImagesUpload = _uploadAdditionalImages(productId);

      final mainImageUrl = await mainImageUpload;
      final additionalImageUrls = await additionalImagesUpload;

      // Add product to the seller's shop
      await newProductRef.set({
        'product_id': productId,
        'name': productName,
        'price': productPrice,
        'description': productDescription,
        'stocks': productStocks,
        'category': productCategory,
        'profileImageUrl': mainImageUrl,
        'additionalImages': additionalImageUrls,
        'product_story': productStory,
        'product_details': productDetails,
        'total_sold': 0, // Initialize total_sold to 0
      });

      // Add product to public shops
      await _addToPublicShops(productId, mainImageUrl, additionalImageUrls);

      Navigator.of(context).pop(); // Dismiss loading dialog
      Navigator.of(context).pop(); // Close product add dialog
    } catch (error) {
      Navigator.of(context).pop(); // Dismiss loading dialog in case of error
      print('Error uploading product: $error');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Product'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: _pickMainImage,
              icon: const Icon(Icons.image),
              label: const Text('Pick Main Image'),
            ),
            if (_mainImageFile != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.file(_mainImageFile!, height: 100, width: 100),
              ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(labelText: 'Product Name'),
              onChanged: (value) => productName = value,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Price'),
              keyboardType: TextInputType.number,
              onChanged: (value) => productPrice = value,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Available Stocks'),
              keyboardType: TextInputType.number,
              onChanged: (value) => productStocks = value,
            ),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Category'),
              value: productCategory,
              items: _categories
                  .map((category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ))
                  .toList(),
              onChanged: (newValue) =>
                  setState(() => productCategory = newValue!),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(labelText: 'Product Story'),
              onChanged: (value) => productStory = value,
            ),
            TextField(
              decoration:
                  const InputDecoration(labelText: 'Product Description'),
              onChanged: (value) => productDescription = value,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Details'),
              onChanged: (value) => productDetails = value,
            ),
            const SizedBox(height: 10),
            const Text(
              'Add More Images:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: _pickAdditionalImage,
              icon: const Icon(Icons.image),
              label: const Text('Add Image'),
            ),
            Wrap(
              children: _additionalImageFiles.map((file) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.file(file, height: 80, width: 80),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isUploading ? null : _uploadProduct,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
