import 'package:capstone/components/botton_navbar.dart';
import 'package:capstone/components/navbar.dart';
import 'package:capstone/components/shop_details.dart';
import 'package:capstone/login/login.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:video_player/video_player.dart';

class BuyerHomePage extends StatefulWidget {
  @override
  _BuyerHomePageState createState() => _BuyerHomePageState();
}

class _BuyerHomePageState extends State<BuyerHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _publicProductsRef =
      FirebaseDatabase.instance.reference().child('shops/public_shops');

  int _currentCarouselIndex = 0;
  String _selectedCategory = 'All Categories';
  VideoPlayerController? _videoController;
  bool _isVideoPlaying = false;

  final List<String> mediaList = [
    'img/image1.jpg',
    'img/image2.jpg',
    'img/image3.jpg',
    'img/video.mp4',
  ];

  final List<Map<String, dynamic>> categories = [
    {'label': 'All Categories', 'image': 'img/allc.jpg'},
    {'label': 'Bags', 'image': 'img/c1.jpg'},
    {'label': 'Necklaces', 'image': 'img/c3.jpg'},
    {'label': 'Shoes', 'image': 'img/c2.jpg'},
    {'label': 'Blankets', 'image': 'img/c4.jpg'},
    {'label': 'Earrings', 'image': 'img/c5.jpg'},
    {'label': 'Baskets', 'image': 'img/c6.jpg'},
    {'label': 'Clothes', 'image': 'img/c7.png'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }
 
  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _initializeVideoPlayer() {
    _videoController = VideoPlayerController.asset('img/video.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            if (_currentCarouselIndex ==
                mediaList.indexWhere((media) => media.endsWith('.mp4'))) {
              _videoController!.play();
              _isVideoPlaying = true;
            } else {
              _videoController!.pause();
              _isVideoPlaying = false;
            }
          });
        }
      }).catchError((error) {
        print('Error initializing video player: $error');
      });
  }

  void _handleCarouselPageChange(int index, CarouselPageChangedReason reason) {
    setState(() {
      _currentCarouselIndex = index;
      bool isVideo = mediaList[index].endsWith('.mp4');

      if (isVideo) {
        _videoController?.play();
        _isVideoPlaying = true;
      } else {
        _videoController?.pause();
        _isVideoPlaying = false;
      }
    });
  }

  // Function to show fullscreen view of the image or video
  void _showFullscreenMedia(String mediaPath) {
    bool isVideo = mediaPath.endsWith('.mp4');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isVideo &&
                  _videoController != null &&
                  _videoController!.value.isInitialized)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isVideoPlaying = !_isVideoPlaying;
                      if (_isVideoPlaying) {
                        _videoController!.play();
                      } else {
                        _videoController!.pause();
                      }
                    });
                  },
                  child: VideoPlayer(_videoController!),
                )
              else
                Image.asset(
                  mediaPath,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              Positioned(
                top: 30,
                right: 30,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (isVideo) {
                      _videoController?.pause();
                    }
                  },
                ),
              ),
              if (isVideo && !_isVideoPlaying)
                Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 80,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    await _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    if (user == null) {
      return LoginScreen();
    }

    String userId = user.uid;
    String userType = "Buyer";
    double deviceWidth = MediaQuery.of(context).size.width;
    bool isWeb = deviceWidth > 600;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Column(
          children: [
            Navbar(userId: userId, userType: userType),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildCarousel(isWeb),
                    const SizedBox(height: 10),
                    _buildDotsIndicator(),
                    const SizedBox(height: 20),
                    _buildCategorySection(isWeb),
                    const SizedBox(height: 20),
                    _buildPopularProductsRow(isWeb),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: deviceWidth <= 600
            ? BottomNavBar(userId: userId, userType: userType)
            : null,
      ),
    );
  }

  Widget _buildCarousel(bool isWeb) {
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isWeb ? 50.0 : 0.0),
          child: CarouselSlider(
            options: CarouselOptions(
              height: isWeb ? 400 : 220,
              autoPlay: !_isVideoPlaying,
              enlargeCenterPage: true,
              autoPlayInterval: const Duration(seconds: 10),
              autoPlayAnimationDuration: const Duration(milliseconds: 1200),
              autoPlayCurve: Curves.fastOutSlowIn,
              viewportFraction: 1.0,
              onPageChanged: _handleCarouselPageChange,
            ),
            items: mediaList.map((mediaPath) {
              bool isVideo = mediaPath.endsWith('.mp4');
              return GestureDetector(
                onTap: () {
                  _showFullscreenMedia(mediaPath);
                },
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.7,
                  margin: const EdgeInsets.symmetric(horizontal: 5.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15.0),
                    color: Colors.black,
                  ),
                  child: isVideo
                      ? _buildVideoPlayer()
                      : Image.asset(
                          mediaPath,
                          fit: BoxFit.cover,
                        ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    return _videoController != null && _videoController!.value.isInitialized
        ? GestureDetector(
            onTap: () {
              setState(() {
                _isVideoPlaying = !_isVideoPlaying;
                if (_isVideoPlaying) {
                  _videoController!.play();
                } else {
                  _videoController!.pause();
                }
              });
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
                if (!_isVideoPlaying)
                  const Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 60,
                  ),
              ],
            ),
          )
        : const Center(child: CircularProgressIndicator());
  }

  Widget _buildDotsIndicator() {
    return DotsIndicator(
      dotsCount: mediaList.length,
      position: _currentCarouselIndex,
      decorator: DotsDecorator(
        activeColor: Colors.red[900],
        size: const Size.square(9.0),
        activeSize: const Size(18.0, 9.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5.0),
        ),
        spacing: const EdgeInsets.symmetric(horizontal: 4.0),
      ),
    );
  }

  Widget _buildCategorySection(bool isWeb) {
    return Column(
      crossAxisAlignment:
          isWeb ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
              left: isWeb ? 0.0 : 8.0), // Center on web, left align on mobile
          child: Text(
            'Categories',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isWeb ? 80.0 : 0.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: categories.map((category) {
                bool isSelected = category['label'] == _selectedCategory;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory =
                          isSelected ? 'All Categories' : category['label'];
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.red, width: 2)
                                : null,
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              category['image'],
                              width: isWeb ? 50 : 70,
                              height: isWeb ? 50 : 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category['label'],
                          style: TextStyle(
                            fontSize: isWeb ? 10 : 12,
                            color: isSelected ? Colors.red : Colors.black,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPopularProductsRow(bool isWeb) {
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
          if (_selectedCategory == 'All Categories' ||
              value['category'] == _selectedCategory) {
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
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWeb ? 5 : 2,
            childAspectRatio: isWeb ? 0.9 : 0.7,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: products.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            return _buildProductCard(products[index], isWeb);
          },
        );
      },
    );
  }

  Widget _buildProductCard(Map product, bool isWeb) {
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
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 3,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(isWeb ? 8 : 12),
              child: Image.network(
                product['profileImageUrl'],
                height: isWeb ? 300 : 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'By ${product['seller_name'] ?? 'Unknown Seller'}',
              style: TextStyle(
                fontSize: isWeb ? 12 : 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              product['name'],
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isWeb ? 14 : 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '₱${product['price']}',
              style: TextStyle(
                fontSize: isWeb ? 16 : 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
