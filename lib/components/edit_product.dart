import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class EditProductModal {
  final DatabaseReference _databaseRef;
  final String userId;
  final Map<String, dynamic> product;

  EditProductModal({
    required DatabaseReference databaseRef,
    required this.userId,
    required this.product,
  }) : _databaseRef = databaseRef;

  Future<void> show(BuildContext context) async {
    TextEditingController nameController =
        TextEditingController(text: product['name']);
    TextEditingController priceController =
        TextEditingController(text: product['price']);
    TextEditingController descriptionController =
        TextEditingController(text: product['description']);
    TextEditingController quantityController =
        TextEditingController(text: product['quantity']);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            'Edit Product',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Product Name Input
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Product Name',
                      prefixIcon: const Icon(Icons.label),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                // Price Input
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: 'Price',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),

                // Description Input
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      prefixIcon: const Icon(Icons.description),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                // Quantity Input
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      prefixIcon: const Icon(Icons.production_quantity_limits),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Cancel Button
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Save Button
                  ElevatedButton(
                    onPressed: () async {
                      String updatedName = nameController.text;
                      String updatedPrice = priceController.text;
                      String updatedDescription = descriptionController.text;
                      String updatedQuantity = quantityController.text;

                      if (updatedName.isNotEmpty && updatedPrice.isNotEmpty) {
                        await _databaseRef
                            .child(userId)
                            .child('products')
                            .child(product['id']!)
                            .update({
                          'name': updatedName,
                          'price': updatedPrice,
                          'description': updatedDescription,
                          'quantity': updatedQuantity,
                        });
                      }

                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      primary: Colors.green[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
