import 'package:capstone/components/chat_list.dart';
import 'package:capstone/components/notification.dart';
import 'package:flutter/material.dart';
import 'package:capstone/components/cart.dart';
import 'package:capstone/components/shop.dart';
import 'package:capstone/components/orders_buyer.dart';
import 'package:capstone/home/buyer_page.dart';

import '../home/admin_page.dart';
import '../home/seller_page.dart';
import '../login/login.dart';
import 'profile_page.dart';
import 'user_management.dart'; // Import UserManagement page
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class Navbar extends StatefulWidget {
  final String userId;
  final String userType;

  Navbar({
    required this.userId,
    required this.userType,
  });

  @override
  _NavbarState createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  int notificationCount = 0;
  int chatUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.userType == 'Buyer') {
      _fetchNotificationCount();
      _fetchUnreadChatCount();
    }
  }

  Future<void> _fetchNotificationCount() async {
    final DatabaseReference checkoutsRef =
        FirebaseDatabase.instance.ref('checkouts');
    final DataSnapshot snapshot = await checkoutsRef.get();
    int unreadCount = 0;

    if (snapshot.exists) {
      for (var child in snapshot.children) {
        final data = child.value as Map<dynamic, dynamic>?;
        if (data != null &&
            data['status'] == 'Processed' &&
            (data['notification_read_buyers'] != true)) {
          unreadCount++;
        }
      }
    }

    setState(() {
      notificationCount = unreadCount;
    });
  }

  Future<void> _fetchUnreadChatCount() async {
    final DatabaseReference chatsRef = FirebaseDatabase.instance.ref('chats');
    final DataSnapshot snapshot = await chatsRef.get();
    int unreadCount = 0;

    if (snapshot.exists) {
      final chatData = snapshot.value as Map<dynamic, dynamic>?;
      if (chatData != null) {
        for (var chat in chatData.values) {
          final messages = (chat['messages'] as Map<dynamic, dynamic>?) ?? {};
          for (var message in messages.values) {
            if (message['recipientId'] == widget.userId &&
                message['notification_read'] == false) {
              unreadCount++;
            }
          }
        }
      }
    }

    setState(() {
      chatUnreadCount = unreadCount;
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (context) => LoginScreen()), // Replace with your login page
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isWeb = MediaQuery.of(context).size.width > 600;

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isLargeScreen = constraints.maxWidth > 600;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          color: Colors.red[900],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: const Text(
                  'HANDIMERCE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontFamily: 'Serif',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isLargeScreen) ...[
                      _buildNavButton(context, 'Home'),
                      const SizedBox(width: 20),
                      if (widget.userType != 'Admin') ...[
                        _buildNavButton(context, 'Shop'),
                        const SizedBox(width: 20),
                      ],
                      if (widget.userType == 'Buyer') ...[
                        _buildNavButton(context, 'Orders'),
                        const SizedBox(width: 20),
                      ],
                      if (widget.userType == 'Admin') ...[
                        _buildNavButton(context, 'Users'),
                        const SizedBox(width: 20),
                      ],
                      _buildProfileButton(context, widget.userId),
                      const SizedBox(width: 20),
                      if (isWeb && widget.userType == 'Buyer')
                        _buildNotificationIconButton(),
                      const SizedBox(width: 20),
                      if (isWeb && widget.userType == 'Buyer')
                        _buildChatIconButton(),
                    ],
                    if (widget.userType != 'Admin')
                      _buildCartIconButton(context),
                    if (isWeb) ...[
                      const SizedBox(width: 20),
                      _buildLogoutIconButton(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartIconButton(BuildContext context) {
    // Only show the cart icon for non-admin users
    return FutureBuilder<int>(
      future: _fetchCartItemCount(),
      builder: (context, snapshot) {
        int itemCount = snapshot.data ?? 0;
        return Badge(
          alignment: AlignmentDirectional.topEnd,
          offset: const Offset(-5, 5),
          isLabelVisible: itemCount > 0,
          backgroundColor: Color.fromARGB(255, 107, 0, 0),
          label: Text(
            '$itemCount',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          child: IconButton(
            icon: const Icon(Icons.shopping_cart, color: Colors.white),
            onPressed: () {
              _navigateWithFadeTransition(context, ShoppingCartPage());
            },
          ),
        );
      },
    );
  }

  Widget _buildNotificationIconButton() {
    return Badge(
      isLabelVisible: notificationCount > 0,
      label: Text(
        '$notificationCount',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: Colors.red,
      child: IconButton(
        icon: const Icon(Icons.notifications, color: Colors.white),
        onPressed: () => _showNotificationDialog(context),
      ),
    );
  }

  Widget _buildChatIconButton() {
    return Badge(
      isLabelVisible: chatUnreadCount > 0,
      label: Text(
        '$chatUnreadCount',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: Colors.red,
      child: IconButton(
        icon: const Icon(Icons.chat, color: Colors.white),
        onPressed: () => _navigateWithFadeTransition(
          context,
          ChatListPage(
            userId: widget.userId,
            userType: widget.userType,
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutIconButton() {
    return IconButton(
      icon: const Icon(Icons.logout, color: Colors.white),
      onPressed: _logout,
    );
  }

  Future<int> _fetchCartItemCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final String? uid = user?.uid;
      if (uid == null) return 0;

      final DatabaseReference cartRef =
          FirebaseDatabase.instance.ref('shoppingCart/$uid');
      final DataSnapshot cartSnapshot = await cartRef.get();

      if (cartSnapshot.exists && cartSnapshot.value != null) {
        final data = cartSnapshot.value as Map<dynamic, dynamic>;
        int itemCount = 0;

        for (var item in data.values) {
          int quantity = item['quantity'] ?? 1;
          itemCount += quantity;
        }
        return itemCount;
      }
    } catch (e) {
      print("Error fetching cart item count: $e");
    }
    return 0;
  }

  void _showNotificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: NotificationsDialog(
            userId: widget.userId,
            userType: widget.userType,
          ),
        );
      },
    );
  }

  void _navigateWithFadeTransition(BuildContext context, Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildProfileButton(BuildContext context, String userId) {
    return TextButton(
      onPressed: () {
        _showProfileModal(context, userId);
      },
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.red[900],
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text(
        'Profile',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showProfileModal(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ProfilePage(userId: userId);
      },
    );
  }

  Widget _buildNavButton(BuildContext context, String label) {
    return TextButton(
      onPressed: () {
        if (label == 'Home') {
          // Navigate based on userType
          if (widget.userType == 'Admin') {
            _navigateWithFadeTransition(context, AdminHomePage());
          } else if (widget.userType == 'Seller') {
            _navigateWithFadeTransition(context, SellerHomePage());
          } else if (widget.userType == 'Buyer') {
            _navigateWithFadeTransition(context, BuyerHomePage());
          }
        } else if (label == 'Shop' && widget.userType != 'Admin') {
          _navigateWithFadeTransition(
            context,
            ShopPage(userType: widget.userType, userId: widget.userId),
          );
        } else if (label == 'Orders') {
          _navigateWithFadeTransition(
            context,
            OrderProductsPage(userId: widget.userId),
          );
        } else if (label == 'Users' && widget.userType == 'Admin') {
          _navigateWithFadeTransition(
            context,
            UserManagementPage(
                userId: widget.userId, userType: widget.userType),
          ); // Navigate to UserManagement page for Admins
        }
      },
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.red[900],
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
