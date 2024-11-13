import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'checkout.dart'; // Import the CheckoutPage

class ShoppingCartPage extends StatefulWidget {
  @override
  _ShoppingCartPageState createState() => _ShoppingCartPageState();
}

class _ShoppingCartPageState extends State<ShoppingCartPage> {
  List<Map<String, dynamic>> cartItems = [];
  bool isLoading = true;
  double totalPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchCartItems();
  }

  Future<void> _fetchCartItems() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      final String? uid = user?.uid;

      if (uid == null) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You need to be logged in to view the cart!')),
        );
        return;
      }

      final DatabaseReference cartRef =
          FirebaseDatabase.instance.ref('shoppingCart/$uid');
      final DataSnapshot cartSnapshot = await cartRef.get();

      if (cartSnapshot.exists && cartSnapshot.value != null) {
        final List<Map<String, dynamic>> loadedItems = [];
        final data = cartSnapshot.value as Map<dynamic, dynamic>;

        double calculatedTotalPrice = 0.0;

        // Reference to public products for validation
        final DatabaseReference publicProductsRef =
            FirebaseDatabase.instance.ref('shops/public_shops');

        // Validate each item in the cart
        for (var key in data.keys) {
          final itemData = data[key] as Map<dynamic, dynamic>;
          final DataSnapshot publicProductSnapshot =
              await publicProductsRef.child(key).get();

          // If product is not found in public_shops, mark it as deleted
          if (!publicProductSnapshot.exists) {
            itemData['isDeleted'] = true;
          } else {
            itemData['isDeleted'] = false;
          }

          final item = Map<String, dynamic>.from(itemData)..['key'] = key;
          item['quantity'] = item['quantity'] ?? 1;
          loadedItems.add(item);

          if (!item['isDeleted']) {
            double itemPrice =
                double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
            calculatedTotalPrice += itemPrice * item['quantity'];
          }
        }

        setState(() {
          cartItems = loadedItems;
          totalPrice = calculatedTotalPrice;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          cartItems = [];
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading cart items: $e')),
      );
    }
  }

  Future<void> _removeItem(String key) async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? uid = user?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You need to be logged in to remove items!')),
      );
      return;
    }

    final DatabaseReference itemRef =
        FirebaseDatabase.instance.ref('shoppingCart/$uid/$key');
    await itemRef.remove();

    setState(() {
      cartItems.removeWhere((item) => item['key'] == key);
      _calculateTotalPrice();
    });
  }

  Future<void> _increaseQuantity(
      String key, int currentQuantity, int maxStock) async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? uid = user?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You need to be logged in to increase quantity!')),
      );
      return;
    }

    if (currentQuantity >= maxStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot exceed available stock of $maxStock')),
      );
      return;
    }

    final DatabaseReference itemRef =
        FirebaseDatabase.instance.ref('shoppingCart/$uid/$key');

    await itemRef.update({'quantity': currentQuantity + 1});

    setState(() {
      cartItems.firstWhere((item) => item['key'] == key)['quantity'] =
          currentQuantity + 1;
      _calculateTotalPrice();
    });
  }

  Future<void> _decreaseQuantity(String key, int currentQuantity) async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? uid = user?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You need to be logged in to decrease quantity!')),
      );
      return;
    }

    if (currentQuantity <= 1) {
      await _removeItem(key);
      return;
    }

    final DatabaseReference itemRef =
        FirebaseDatabase.instance.ref('shoppingCart/$uid/$key');

    await itemRef.update({'quantity': currentQuantity - 1});

    setState(() {
      cartItems.firstWhere((item) => item['key'] == key)['quantity'] =
          currentQuantity - 1;
      _calculateTotalPrice();
    });
  }

  void _calculateTotalPrice() {
    double calculatedTotalPrice = 0.0;

    for (var item in cartItems) {
      if (!item['isDeleted']) {
        double itemPrice =
            double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
        int quantity = item['quantity'] ?? 1;
        calculatedTotalPrice += itemPrice * quantity;
      }
    }

    setState(() {
      totalPrice = calculatedTotalPrice;
    });
  }

  void _checkout() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? uid = user?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You need to be logged in to proceed to checkout!')),
      );
      return;
    }

    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Your cart is empty! Please add items to proceed.')),
      );
      return;
    }

    // Extract sellerId from the first cart item or provide a default/fallback value
    String? sellerId = cartItems.first['seller_id'];

    if (sellerId == null || sellerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to find seller information.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutPage(
          totalPrice: totalPrice,
          cartItems: cartItems,
          sellerId:
              sellerId, // Ensure sellerId is provided as a non-null String
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.red,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : cartItems.isEmpty
              ? const Center(child: Text('Your cart is empty!'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: cartItems.length,
                        itemBuilder: (context, index) {
                          return _buildCartItem(cartItems[index]);
                        },
                      ),
                    ),
                    _buildTotalPriceSection(),
                  ],
                ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    int quantity = item['quantity'] ?? 1;
    int maxStock = int.tryParse(item['stock']?.toString() ?? '0') ?? 0;
    bool isDeleted = item['isDeleted'] == true;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            item['imageUrl'] != null && item['imageUrl'].isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item['imageUrl'],
                      fit: BoxFit.cover,
                      width: 60,
                      height: 60,
                    ),
                  )
                : const Icon(Icons.shopping_bag, size: 60, color: Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] ?? 'Unknown Product',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (isDeleted)
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'This product has been deleted',
                            style: TextStyle(color: Colors.red, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () {
                              _removeItem(item['key']);
                            },
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₱${(double.tryParse(item['price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Quantity: $quantity'),
                        Text('Available Stock: ${item['stock']}'),
                      ],
                    ),
                ],
              ),
            ),
            if (!isDeleted)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle,
                        color: Colors.green, size: 24),
                    onPressed: () {
                      _increaseQuantity(item['key'], quantity, maxStock);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle,
                        color: Colors.red, size: 24),
                    onPressed: () {
                      _decreaseQuantity(item['key'], quantity);
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalPriceSection() {
    bool isCheckoutDisabled = cartItems.isEmpty || totalPrice <= 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₱${totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: isCheckoutDisabled ? null : _checkout,
            style: ElevatedButton.styleFrom(
              backgroundColor: isCheckoutDisabled ? Colors.grey : Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Checkout',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
