import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class ProductDetailsDialog {
  static void show(BuildContext context, Map<String, dynamic> product) {
    String? profileImageUrl = product['profileImageUrl'];
    List<String>? additionalImages = product['additionalImages'] != null
        ? List<String>.from(product['additionalImages'])
        : [];

    // Combine profile image with additional images for carousel
    List<String> imageUrls =
        [if (profileImageUrl != null) profileImageUrl] + additionalImages;

    // Page controller to control the page view and dots
    PageController pageController = PageController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isMobile =
            MediaQuery.of(context).size.width < 600; // Check if mobile
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8.0,
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile
                  ? double.infinity
                  : 400, // Max width for larger screens
              minWidth: 300, // Minimum width
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image Carousel with arrow controls
                  _buildImageCarousel(
                      imageUrls, product['price'], pageController),

                  const SizedBox(height: 16),

                  // Dot Indicator for images
                  Center(
                    child: SmoothPageIndicator(
                      controller: pageController,
                      count: imageUrls.length,
                      effect: ExpandingDotsEffect(
                        dotHeight: 8,
                        dotWidth: 8,
                        activeDotColor: Colors.redAccent,
                        dotColor: Colors.grey.shade300,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Product Name
                  Text(
                    product['name'] ?? 'Unnamed Product',
                    style: const TextStyle(
                      fontSize: 24, // Larger size for product name
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  Text(
                    product['description'] ?? 'No description available',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stocks and Stock Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available Stocks: ${product['stocks'] ?? '0'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: (product['stocks'] == 0 ||
                                  product['stocks'] == '0')
                              ? Colors.red[600]
                              : Colors.green[600],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (product['stocks'] == 0 || product['stocks'] == '0')
                              ? 'No Stocks'
                              : 'In Stock',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Centered Close Button
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 32,
                        ),
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method to build the image carousel with arrows and dot indicators
  static Widget _buildImageCarousel(
      List<String> imageUrls, String? price, PageController pageController) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 220,
          width: double.infinity,
          child: PageView.builder(
            controller: pageController,
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              final imageUrl = imageUrls[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: Image.network(
                  imageUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 220,
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 80,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),

        // Price Overlay with Peso Icon and smaller font size
        if (price != null)
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '₱$price', // Peso sign instead of Dollar sign
                style: const TextStyle(
                  fontSize: 16, // Smaller font size for price
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Left Arrow Button with Circular Black Background
        Positioned(
          left: 8,
          child: Container(
            height: 32, // Smaller circular background
            width: 32, // Smaller circular background
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black, // Circular black background
            ),
            child: IconButton(
              iconSize: 16, // Smaller icon
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () {
                pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ),
        ),

        // Right Arrow Button with Circular Black Background
        Positioned(
          right: 8,
          child: Container(
            height: 32, // Smaller circular background
            width: 32, // Smaller circular background
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black, // Circular black background
            ),
            child: IconButton(
              iconSize: 16, // Smaller icon
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
              onPressed: () {
                pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
