import 'package:capstone/components/botton_navbar.dart';
import 'package:capstone/login/login.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone/components/navbar.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:carousel_slider/carousel_slider.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  int _totalUserCount = 0;
  int _buyerCount = 0;
  int _sellerCount = 0;
  int _shopCount = 0;
  int _currentCarouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _countUsers();
    _countShops();
  }

  Future<void> _countUsers() async {
    try {
      final snapshot = await _database.child('users').get();

      if (snapshot.exists) {
        int total = 0;
        int buyers = 0;
        int sellers = 0;

        for (var userSnapshot in snapshot.children) {
          total++;

          final userTypeSnapshot = userSnapshot.child('userprofiles/user_type');
          if (userTypeSnapshot.exists) {
            String userType = userTypeSnapshot.value as String;
            if (userType == "Buyer") {
              buyers++;
            } else if (userType == "Seller") {
              sellers++;
            }
          }
        }

        setState(() {
          _totalUserCount = total;
          _buyerCount = buyers;
          _sellerCount = sellers;
        });
      } else {
        setState(() {
          _totalUserCount = 0;
          _buyerCount = 0;
          _sellerCount = 0;
        });
      }
    } catch (e) {
      print("Error counting users: $e");
    }
  }

  Future<void> _countShops() async {
    try {
      final snapshot = await _database.child('shops/public_shops').get();

      if (snapshot.exists) {
        setState(() {
          _shopCount = snapshot.children.length;
        });
      } else {
        setState(() {
          _shopCount = 0;
        });
      }
    } catch (e) {
      print("Error counting shops: $e");
    }
  }

  Future<void> _logout(BuildContext context) async {
    await _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    String userId = user.uid;
    String userType = "Admin";

    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            bool isMobile = constraints.maxWidth < 600;

            return SingleChildScrollView(
              child: Column(
                children: [
                  Navbar(userId: userId, userType: userType),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Welcome, Admin!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: isMobile
                        ? Column(
                            children: _buildInfoCards(isMobile),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: _buildInfoCards(isMobile),
                          ),
                  ),
                  const SizedBox(height: 24),
                  _buildImageCarousel(isMobile),
                  const SizedBox(height: 16),
                  _buildDotIndicator(),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: MediaQuery.of(context).size.width <= 600
            ? BottomNavBar(userId: userId, userType: userType)
            : null,
      ),
    );
  }

  List<Widget> _buildInfoCards(bool isMobile) {
    return [
      _buildInfoCard(
        icon: Icons.people,
        label: 'Total Users',
        count: _totalUserCount,
        color: Colors.blue,
        isMobile: isMobile,
      ),
      _buildInfoCard(
        icon: Icons.shopping_cart,
        label: 'Total Buyers',
        count: _buyerCount,
        color: Colors.green,
        isMobile: isMobile,
      ),
      _buildInfoCard(
        icon: Icons.store,
        label: 'Total Sellers',
        count: _sellerCount,
        color: Colors.orange,
        isMobile: isMobile,
      ),
      _buildInfoCard(
        icon: Icons.business,
        label: 'Total Products',
        count: _shopCount,
        color: Colors.purple,
        isMobile: isMobile,
      ),
    ];
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required bool isMobile,
  }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? double.infinity : 200,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: isMobile ? 36 : 40),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: isMobile ? 20 : 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCarousel(bool isMobile) {
    List<String> images = [
      'img/image1.jpg',
      'img/image2.jpg',
      'img/image3.jpg',
    ];

    return CarouselSlider(
      items: images.map((imagePath) {
        return Builder(
          builder: (BuildContext context) {
            return Container(
              width: MediaQuery.of(context).size.width * (isMobile ? 0.8 : 0.9),
              margin: const EdgeInsets.symmetric(horizontal: 5.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: AssetImage(imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
        );
      }).toList(),
      options: CarouselOptions(
        height: isMobile ? 250 : 400,
        autoPlay: true,
        enlargeCenterPage: true,
        aspectRatio: 16 / 9,
        autoPlayCurve: Curves.fastOutSlowIn,
        enableInfiniteScroll: true,
        autoPlayAnimationDuration: const Duration(milliseconds: 800),
        viewportFraction: isMobile ? 0.8 : 0.9,
        onPageChanged: (index, reason) {
          setState(() {
            _currentCarouselIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildDotIndicator() {
    List<String> images = [
      'img/image1.jpg',
      'img/image2.jpg',
      'img/image3.jpg',
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: images.asMap().entries.map((entry) {
        return GestureDetector(
          onTap: () => setState(() => _currentCarouselIndex = entry.key),
          child: Container(
            width: 12.0,
            height: 12.0,
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black)
                  .withOpacity(_currentCarouselIndex == entry.key ? 0.9 : 0.4),
            ),
          ),
        );
      }).toList(),
    );
  }
}
