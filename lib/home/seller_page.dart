import 'package:capstone/components/botton_navbar.dart';
import 'package:capstone/login/login.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:capstone/components/navbar.dart';

class SellerHomePage extends StatefulWidget {
  @override
  _SellerHomePageState createState() => _SellerHomePageState();
}

class _SellerHomePageState extends State<SellerHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  bool _isLoading = true;
  bool _isApproved = false;
  DatabaseReference? _userProfileRef;

  Future<void> _logout(BuildContext context) async {
    await _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkApprovalStatus();
  }

  @override
  void dispose() {
    _userProfileRef?.onValue.drain();
    super.dispose();
  }

  Future<void> _checkApprovalStatus() async {
    User? user = _auth.currentUser;
    if (user != null) {
      _userProfileRef =
          _database.child('users').child(user.uid).child('userprofiles');
      _userProfileRef!.onValue.listen((event) {
        if (event.snapshot.exists) {
          Map<dynamic, dynamic> userData =
              event.snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            _isApproved = userData['seller_approval'] == true;
            _isLoading = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width <= 600;
    User? user = _auth.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    String userId = user.uid;
    String userType = "Seller";

    return WillPopScope(
      onWillPop: () async {
        // Prevent back navigation to the login screen
        return false;
      },
      child: Scaffold(
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                children: [
                  if (_isApproved)
                    Navbar(
                      userId: userId,
                      userType: userType,
                    ),
                  Expanded(
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              // Welcome message with dark red style
                              Text(
                                'Welcome, Seller!',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[900], // Dark Red
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Vision section
                              _buildSection(
                                title: 'Vision',
                                description:
                                    'Our vision is to empower sellers to reach their full potential through our platform, fostering growth and success.',
                                backgroundColor: Colors.red[700]!,
                              ),
                              // Mission section
                              _buildSection(
                                title: 'Mission',
                                description:
                                    'Our mission is to provide an intuitive platform that helps sellers connect with buyers, streamlining the process of selling products online.',
                                backgroundColor: Colors.red[600]!,
                              ),
                              // Goals section
                              _buildSection(
                                title: 'Goals',
                                description:
                                    '1. Enhance seller tools.\n2. Improve buyer-seller communication.\n3. Foster a thriving seller community.',
                                backgroundColor: Colors.red[500]!,
                              ),
                              const SizedBox(height: 20),
                              // Image section with a shadow and rounded corners
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.asset(
                                    'img/sellerbg.jpg', // Use the asset image instead of network image
                                    height: 200,
                                    width: double
                                        .infinity, // Make it responsive to the width
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                        if (!_isApproved)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withOpacity(0.7),
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
                          ),
                      ],
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: isMobile
            ? BottomNavBar(
                userId: userId,
                userType: userType,
                selectedIndex: 0,
              )
            : null,
      ),
    );
  }

  // Helper method to build the Vision, Mission, Goals sections with dark red palette
  Widget _buildSection({
    required String title,
    required String description,
    required Color backgroundColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white, // White text for better contrast
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70, // Light grey text for description
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
