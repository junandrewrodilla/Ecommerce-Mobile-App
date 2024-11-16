import 'package:capstone/components/cart.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:badges/badges.dart' as badges;

class ProductDetailsPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsPage({super.key, required this.product});

  @override
  _ProductDetailsPageState createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  String _currentImageUrl = '';

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.product['profileImageUrl'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.product['name'],
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 25,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.red,
        actions: [
          StreamBuilder<int>(
            stream: _getCartItemCountStream(),
            builder: (context, snapshot) {
              int itemCount = snapshot.data ?? 0;

              return badges.Badge(
                position: badges.BadgePosition.topEnd(top: 0, end: 3),
                showBadge: itemCount > 0,
                badgeContent: Text(
                  itemCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.shopping_cart,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ShoppingCartPage(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  // Desktop or larger screen layout
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _buildMainImage(context),
                            const SizedBox(height: 16),
                            _buildThumbnailRow(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProductDetails(),
                            const SizedBox(height: 16),
                            _buildProductInfoSection(),
                            const SizedBox(height: 16),
                            _buildProductDetailsButton(context),
                            const SizedBox(height: 24),
                            _buildAddToCartButton(),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  // Mobile layout
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMainImage(context),
                        const SizedBox(height: 16),
                        _buildThumbnailRow(),
                        const SizedBox(height: 16),
                        _buildProductDetails(),
                        const SizedBox(height: 16),
                        _buildProductInfoSection(),
                        const SizedBox(height: 16),
                        _buildProductDetailsButton(context),
                        const SizedBox(height: 16),
                        _buildAddToCartButton(),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Stream<int> _getCartItemCountStream() {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? uid = user?.uid;

    if (uid == null) {
      return Stream.value(0);
    }

    final DatabaseReference cartRef =
        FirebaseDatabase.instance.ref('shoppingCart/$uid');

    return cartRef.onValue.map((event) {
      if (event.snapshot.exists) {
        final Map<dynamic, dynamic>? cartItems =
            event.snapshot.value as Map<dynamic, dynamic>?;
        return cartItems?.length ?? 0;
      } else {
        return 0;
      }
    });
  }

  Widget _buildMainImage(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _currentImageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(
              maxHeight: 400,
              maxWidth: double.infinity,
            ),
            child: Image.network(
              _currentImageUrl,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailRow() {
    List<String> imageUrls = [widget.product['profileImageUrl']];
    if (widget.product['additionalImages'] != null) {
      imageUrls.addAll(widget.product['additionalImages'].cast<String>());
    }

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          String imageUrl = imageUrls[index];

          return GestureDetector(
            onTap: () {
              setState(() {
                _currentImageUrl = imageUrl;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color:
                        _currentImageUrl == imageUrl ? Colors.red : Colors.grey,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(
                      maxHeight: 70,
                      maxWidth: 70,
                    ),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductDetails() {
    int stockCount = int.tryParse(widget.product['stock'].toString()) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.product['seller_name'] ?? 'Unknown Seller',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.product['name'] ?? 'No name available',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: stockCount > 0 ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            stockCount > 0 ? 'Available in stock' : 'No stock available',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Stock: ${stockCount > 0 ? stockCount.toString() : 'N/A'}',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.category, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              widget.product['category'] ?? 'No category available',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product info',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.product['description'] ?? 'No description available.',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildProductDetailsButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          builder: (context) => _buildProductDetailsModal(),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, size: 24, color: Colors.black87),
                SizedBox(width: 12),
                Text(
                  'Product Details',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Icon(Icons.chevron_right, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  Widget _buildProductDetailsModal() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Product details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Story',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.product['product_story'] ?? 'No story available.',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Text(
            'Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.product['product_details'] ?? 'No details available.',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildAddToCartButton() {
    int stockCount = int.tryParse(widget.product['stock'].toString()) ?? 0;
    bool isOutOfStock = stockCount == 0;

    return FutureBuilder<bool>(
      future: _checkIfProductInCart(),
      builder: (context, snapshot) {
        bool isAlreadyInCart = snapshot.data == true;

        return ElevatedButton(
          onPressed: isOutOfStock || isAlreadyInCart
              ? null
              : () async {
                  final User? user = FirebaseAuth.instance.currentUser;
                  final String? uid = user?.uid;

                  if (uid == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('You need to be logged in to add to cart!')),
                    );
                    return;
                  }

                  final String productId = widget.product['id'].toString();
                  final DatabaseReference dbRef = FirebaseDatabase.instance
                      .ref('shoppingCart/$uid/$productId');

                  final product = {
                    'id': productId,
                    'product_id': productId,
                    'seller_id': widget.product['seller_id'].toString(),
                    'name': widget.product['name'],
                    'description': widget.product['description'],
                    'imageUrl': widget.product['profileImageUrl'],
                    'price': widget.product['price'] ?? '0',
                    'quantity': 1,
                    'stock': stockCount,
                  };

                  await dbRef.set(product);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('${widget.product['name']} added to cart!')),
                  );

                  setState(() {
                    isAlreadyInCart = true;
                  });
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: isOutOfStock || isAlreadyInCart
                ? Colors.grey
                : const Color.fromARGB(255, 184, 0, 0),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Center(
            child: Text(
              isOutOfStock
                  ? 'Out of Stock'
                  : isAlreadyInCart
                      ? 'Product already added'
                      : 'Add to Cart',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _checkIfProductInCart() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? uid = user?.uid;

    if (uid == null) {
      return false;
    }

    final String productId = widget.product['id'].toString();
    final DatabaseReference dbRef =
        FirebaseDatabase.instance.ref('shoppingCart/$uid/$productId');
    final DataSnapshot snapshot = await dbRef.get();

    return snapshot.exists;
  }
}
