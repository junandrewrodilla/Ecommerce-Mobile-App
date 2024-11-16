import 'package:capstone/components/addproduct.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:capstone/components/botton_navbar.dart';
import 'package:capstone/home/seller_page.dart';
import 'product_details.dart';

class SellerShopPage extends StatefulWidget {
  final String userId;

  const SellerShopPage({super.key, required this.userId});

  @override
  _SellerShopPageState createState() => _SellerShopPageState();
}

class _SellerShopPageState extends State<SellerShopPage> {
  final DatabaseReference _databaseRef =
      FirebaseDatabase.instance.ref().child('shops');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? _sellerName;
  String? _selectedCategory = 'All';
  bool _showSoldProducts = false;
  String _searchQuery = '';
  bool _isApproved = false;

  final List<String> _categories = [
    'All',
    'Bags',
    'Necklaces',
    'Shoes',
    'Blankets',
    'Earrings',
    'Baskets ',
    'Clothes',
  ];

  @override
  void initState() {
    super.initState();
    _fetchSellerData();
  }

  Future<void> _fetchSellerData() async {
    final DatabaseReference userProfileRef = FirebaseDatabase.instance
        .ref()
        .child('users/${widget.userId}/userprofiles');
    DatabaseEvent event = await userProfileRef.once();

    if (event.snapshot.exists) {
      Map<dynamic, dynamic>? userProfile =
          event.snapshot.value as Map<dynamic, dynamic>?;
      if (userProfile != null) {
        setState(() {
          _sellerName =
              "${userProfile['first_name']} ${userProfile['last_name']}";
          _isApproved = userProfile['seller_approval'] == true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width <= 600;

    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        appBar: _isApproved
            ? AppBar(
                title: const Text('Seller Shop'),
                backgroundColor: Colors.red[900],
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => SellerHomePage()),
                    );
                  },
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      if (_sellerName != null && _isApproved) {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AddProductDialog(
                              userId: widget.userId,
                              databaseRef: _databaseRef,
                              storage: _storage,
                              sellerName: _sellerName!,
                            );
                          },
                        );
                      }
                    },
                  ),
                ],
              )
            : null,
        body: Stack(
          children: [
            Column(
              children: [
                if (_isApproved)
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Search by Product Name',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.toLowerCase();
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SizedBox(
                              width: 150,
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                ),
                                value: _selectedCategory,
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedCategory = newValue;
                                  });
                                },
                                items: _categories
                                    .map<DropdownMenuItem<String>>((category) {
                                  return DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(category),
                                  );
                                }).toList(),
                              ),
                            ),
                            Row(
                              children: [
                                const Text('Show Sold'),
                                Switch(
                                  value: _showSoldProducts,
                                  onChanged: (bool newValue) {
                                    setState(() {
                                      _showSoldProducts = newValue;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                Expanded(child: _buildProductList()),
              ],
            ),
            if (!_isApproved)
              Container(
                color: Colors.black.withOpacity(0.6),
                child: const Center(
                  child: Text(
                    'YOU\'RE NOT APPROVED YET',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: isMobile
            ? BottomNavBar(
                userId: widget.userId,
                userType: 'Seller',
                selectedIndex: 1,
              )
            : null,
      ),
    );
  }

  Widget _buildProductList() {
    return StreamBuilder(
      stream: _databaseRef.child(widget.userId).child('products').onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.hasData && snapshot.data!.snapshot.exists) {
          Map<dynamic, dynamic> productMap =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          if (productMap.isEmpty) {
            return const Center(
              child: Text('No products available'),
            );
          }

          List<Map<String, dynamic>> products = [];
          productMap.forEach((key, value) {
            products.add({
              'id': key,
              'name': value['name'],
              'price': value['price'],
              'description': value['description'],
              'stocks': value['stocks'],
              'profileImageUrl': value['profileImageUrl'],
              'category': value['category'],
              'sold': value['sold'] ?? false,
              'total_sold': value['total_sold'] ?? 0, // Fetch total_sold field
              'additionalImages': value['additionalImages'] ?? [],
            });
          });

          List<Map<String, dynamic>> filteredProducts =
              products.where((product) {
            final matchesCategory = _selectedCategory == null ||
                _selectedCategory == 'All' ||
                product['category'] == _selectedCategory;
            final matchesSearch =
                product['name'].toString().toLowerCase().contains(_searchQuery);

            // Ensure 'total_sold' is treated as an integer for comparison
            int totalSold = 0;
            if (product['total_sold'] != null) {
              totalSold = int.tryParse(product['total_sold'].toString()) ?? 0;
            }

            // Check if we need to show sold products only and filter based on 'total_sold' > 0
            if (_showSoldProducts) {
              return matchesCategory && matchesSearch && totalSold > 0;
            }

            return matchesCategory && matchesSearch;
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                elevation: 5,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: InkWell(
                  onTap: () {
                    ProductDetailsDialog.show(context, product);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: product['profileImageUrl'] != null &&
                                  product['profileImageUrl'] != ''
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Image.network(
                                    product['profileImageUrl'],
                                    height: 80,
                                    width: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.error,
                                        color: Colors.red,
                                        size: 40,
                                      );
                                    },
                                  ),
                                )
                              : const Icon(
                                  Icons.shopping_bag,
                                  size: 40,
                                  color: Colors.red,
                                ),
                        ),
                        const SizedBox(width: 16.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['name'] ?? 'Unnamed Product',
                                style: const TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                product['description'] ??
                                    'No description available',
                                style: const TextStyle(
                                  fontSize: 14.0,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              Row(
                                children: [
                                  Text(
                                    '₱${product['price']}',
                                    style: const TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 16.0),
                                  const Icon(
                                    Icons.shopping_cart,
                                    size: 18.0,
                                    color: Colors.orange,
                                  ),
                                  Text(
                                    'Stocks: ${product['stocks'] ?? '0'}',
                                    style: const TextStyle(
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4.0),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.shopping_basket,
                                    size: 18.0,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    'Total Sold: ${product['total_sold']}',
                                    style: const TextStyle(
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return EditProductDialog(
                                      product: product,
                                      userId: widget.userId,
                                      databaseRef: _databaseRef,
                                    );
                                  },
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                _showDeleteConfirmationDialog(
                                    context, product['id']);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        } else if (snapshot.hasError) {
          return const Center(child: Text('Error loading products'));
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, String productId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: const Text('Are you sure you want to delete this product?'),
          actions: [
            TextButton(
              onPressed: () async {
                await _databaseRef
                    .child(widget.userId)
                    .child('products')
                    .child(productId)
                    .remove();

                DatabaseReference publicShopRef =
                    FirebaseDatabase.instance.ref().child('shops/public_shops');
                await publicShopRef.child(productId).remove();

                Navigator.of(context).pop();
              },
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}

class EditProductDialog extends StatefulWidget {
  final Map<String, dynamic> product;
  final String userId;
  final DatabaseReference databaseRef;

  const EditProductDialog({
    super.key,
    required this.product,
    required this.userId,
    required this.databaseRef,
  });

  @override
  _EditProductDialogState createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late TextEditingController _stocksController;
  String? _selectedCategory;

  // Define the initial list of categories
  final List<String> _categories = [
    'All',
    'Bags',
    'Necklaces',
    'Shoes',
    'Blankets',
    'Earrings',
    'Baskets', // Removed trailing space
    'Clothes',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product['name']);
    _priceController =
        TextEditingController(text: widget.product['price'].toString());
    _descriptionController =
        TextEditingController(text: widget.product['description']);
    _stocksController =
        TextEditingController(text: widget.product['stocks'].toString());

    // Set the selected category, adding it to the list if it's not already there
    _selectedCategory = widget.product['category'];
    if (_selectedCategory != null && !_categories.contains(_selectedCategory)) {
      _categories.add(_selectedCategory!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _stocksController.dispose();
    super.dispose();
  }

  void _updateProduct() {
    // Define the product data to be updated
    Map<String, dynamic> updatedProductData = {
      'name': _nameController.text,
      'price': _priceController.text,
      'description': _descriptionController.text,
      'stocks': _stocksController.text,
      'category': _selectedCategory,
    };

    // Update the seller's shop product
    widget.databaseRef
        .child(widget.userId)
        .child('products')
        .child(widget.product['id'])
        .update(updatedProductData)
        .then((_) {
      // Update the public shop product with the same ID
      DatabaseReference publicShopRef = FirebaseDatabase.instance
          .ref()
          .child('shops/public_shops')
          .child(widget.product['id']);
      publicShopRef.update(updatedProductData).then((_) {
        // Close the dialog after updating both entries
        Navigator.of(context).pop();
      }).catchError((error) {
        print("Failed to update public shop product: $error");
        // Show an error message if needed
      });
    }).catchError((error) {
      print("Failed to update seller shop product: $error");
      // Show an error message if needed
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Product'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Product Name'),
            ),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Price'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: _stocksController,
              decoration: const InputDecoration(labelText: 'Stocks'),
              keyboardType: TextInputType.number,
            ),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue;
                });
              },
              items:
                  _categories.map<DropdownMenuItem<String>>((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _updateProduct,
          child: const Text('Update'),
        ),
      ],
    );
  }
}
