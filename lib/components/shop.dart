import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'navbar.dart';
import 'package:capstone/components/botton_navbar.dart';
import 'shop_details.dart';

class ShopPage extends StatefulWidget {
  final String userId;
  final String userType;

  ShopPage({required this.userId, required this.userType});

  @override
  _ShopPageState createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  int _selectedIndex = 1;
  String _searchQuery = '';

  final DatabaseReference _publicProductsRef =
      FirebaseDatabase.instance.reference().child('shops/public_shops');

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width <= 600;
    int crossAxisCount = isMobile ? 2 : 4; // Use more columns for web

    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                Navbar(userId: widget.userId, userType: widget.userType),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildSearchBar(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPopularProductsGrid(crossAxisCount, isMobile),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: isMobile
            ? BottomNavBar(
                userId: widget.userId,
                userType: widget.userType,
                selectedIndex: _selectedIndex,
              )
            : null,
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        labelText: 'Search product',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: const Icon(Icons.search),
      ),
      onChanged: (query) {
        setState(() {
          _searchQuery = query.toLowerCase();
        });
      },
    );
  }

  Widget _buildPopularProductsGrid(int crossAxisCount, bool isMobile) {
    return StreamBuilder(
      stream: _publicProductsRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error fetching products'));
        }

        if (!snapshot.hasData || !snapshot.data!.snapshot.exists) {
          return const Center(child: Text('No products available'));
        }

        Map<dynamic, dynamic>? productsMap =
            snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;

        if (productsMap == null) {
          return const Center(child: Text('No products available'));
        }

        List<Map<String, dynamic>> products = [];
        productsMap.forEach((key, value) {
          String productName = value['name'].toString().toLowerCase();
          if (productName.contains(_searchQuery)) {
            products.add({
              'id': key,
              'name': value['name'],
              'profileImageUrl': value['profileImageUrl'],
              'price': value['price'],
              'originalPrice': value['originalPrice'],
              'seller_name': value['seller_name'],
              'seller_id': value['seller_id'],
              'quantity': value['quantity'],
              'product_story': value['product_story'],
              'product_details': value['product_details'],
              'description': value['description'],
              'category': value['category'],
              'additionalImages': value['additionalImages'],
              'stock': value['stocks'],
            });
          }
        });

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: isMobile ? 0.65 : 0.75,
          ),
          itemBuilder: (context, index) {
            return _buildProductCard(products[index], isMobile);
          },
        );
      },
    );
  }

  Widget _buildProductCard(Map product, bool isMobile) {
    double price = double.tryParse(product['price'].toString()) ?? 0.0;
    double? originalPrice = product['originalPrice'] != null
        ? double.tryParse(product['originalPrice'].toString())
        : null;
    bool isDiscounted = originalPrice != null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsPage(
              product: Map<String, dynamic>.from(product),
            ),
          ),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(isMobile ? 0.1 : 0.2),
                spreadRadius: 3,
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Image.network(
                      product['profileImageUrl'],
                      height: isMobile ? 150 : 380, // Increased height for web
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (isDiscounted)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_calculateDiscount(price, originalPrice!)}% off',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  product['seller_name'] ?? 'Unknown Seller',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  product['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 14 : 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Text(
                      '₱${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    if (isDiscounted) ...[
                      const SizedBox(width: 8),
                      Text(
                        '₱${originalPrice!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _calculateDiscount(double price, double originalPrice) {
    double discountPercentage = ((originalPrice - price) / originalPrice) * 100;
    return discountPercentage.toStringAsFixed(0);
  }
}
