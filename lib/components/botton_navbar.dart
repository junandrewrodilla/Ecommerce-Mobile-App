import 'dart:async';

import 'package:capstone/components/orders_buyer.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:capstone/components/chatbox.dart';
import 'package:capstone/components/notification.dart';
import 'package:capstone/components/notification_buyer.dart';
import 'package:capstone/components/order_products.dart';
import 'package:capstone/components/seller_shop.dart';
import 'package:capstone/components/user_management.dart';
import 'package:capstone/components/profile_page.dart';
import 'package:capstone/components/shop.dart';
import 'package:capstone/home/admin_page.dart';
import 'package:capstone/home/buyer_page.dart';
import 'package:capstone/home/seller_page.dart';
import 'chat_list.dart';

class BottomNavBar extends StatefulWidget {
  final String userId;
  final String userType;
  final int selectedIndex;

  BottomNavBar({
    required this.userId,
    required this.userType,
    this.selectedIndex = 0,
  });

  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int notificationCount = 0;
  int chatUnreadCount = 0;
  late DatabaseReference _checkoutsRef;
  late DatabaseReference _chatsRef;
  late int _currentIndex;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _checkoutsRef = FirebaseDatabase.instance.ref().child('checkouts');
    _chatsRef = FirebaseDatabase.instance.ref().child('chats');
    _fetchNotificationCount();
    _currentIndex = widget.selectedIndex;

    if (widget.userType != 'Admin') {
      _fetchUnreadChatCount();
    }

    _refreshTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      _fetchNotificationCount();
      if (widget.userType != 'Admin') {
        _fetchUnreadChatCount();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _fetchNotificationCount() {
    _checkoutsRef.onValue.listen((event) {
      int unreadCount = 0;

      if (event.snapshot.exists) {
        for (var child in event.snapshot.children) {
          final data = child.value as Map<dynamic, dynamic>?;

          if (widget.userType == 'Seller') {
            // Count notifications for sellers if `seller_id` matches the logged-in user ID
            if (data != null &&
                data['seller_id'] == widget.userId && // Match seller ID
                data['notification_read'] != true) {
              // Only unread notifications
              unreadCount++;
            }
          } else if (widget.userType == 'Buyer') {
            // Count notifications for buyers if `user_id` matches the logged-in user ID
            if (data != null &&
                data['user_id'] == widget.userId && // Match user ID for buyer
                data['status'] == 'Processed' && // Processed status only
                data['notification_read_buyers'] != true) {
              // Only unread notifications
              unreadCount++;
            }
          }
        }
      }

      setState(() {
        notificationCount = unreadCount;
      });
    });
  }

  void _fetchUnreadChatCount() {
    _chatsRef.once().then((event) {
      int unreadCount = 0;

      final chatData = event.snapshot.value as Map<dynamic, dynamic>?;
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

      setState(() {
        chatUnreadCount = unreadCount;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.red[900],
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white60,
      currentIndex: _currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontSize: 10),
      items: _buildBottomNavItems(),
      onTap: (index) {
        _onItemTapped(context, index);
      },
    );
  }

  List<BottomNavigationBarItem> _buildBottomNavItems() {
    if (widget.userType == 'Admin') {
      return [
        _buildBottomNavItem(Icons.person, 'Home'),
        _buildBottomNavItem(Icons.people, 'Users'),
        _buildBottomNavItem(Icons.person, 'Profile'),
      ];
    } else if (widget.userType == 'Seller') {
      return [
        _buildBottomNavItem(Icons.home, 'Home'),
        _buildBottomNavItem(Icons.store, 'Shop'),
        _buildBottomNavItem(Icons.add_shopping_cart, 'Orders'),
        _buildNotificationNavItem(),
        _buildChatNavItem(),
        _buildBottomNavItem(Icons.person, 'Profile'),
      ];
    } else if (widget.userType == 'Buyer') {
      return [
        _buildBottomNavItem(Icons.home, 'Home'),
        _buildBottomNavItem(Icons.shopping_cart, 'Shop'),
        _buildBottomNavItem(Icons.add_shopping_cart, 'Orders'),
        _buildNotificationNavItem(),
        _buildChatNavItem(),
        _buildBottomNavItem(Icons.person, 'Profile'),
      ];
    } else {
      return [
        _buildBottomNavItem(Icons.home, 'Home'),
        _buildBottomNavItem(Icons.store, 'Shop'),
        _buildChatNavItem(),
        _buildBottomNavItem(Icons.person, 'Profile'),
      ];
    }
  }

  BottomNavigationBarItem _buildBottomNavItem(IconData icon, String label) {
    return BottomNavigationBarItem(
      icon: Icon(icon),
      label: label,
    );
  }

  BottomNavigationBarItem _buildChatNavItem() {
    return BottomNavigationBarItem(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.chat),
          if (chatUnreadCount > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Center(
                  child: Text(
                    '$chatUnreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      label: 'Chat',
    );
  }

  BottomNavigationBarItem _buildNotificationNavItem() {
    return BottomNavigationBarItem(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications),
          if (notificationCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Center(
                  child: Text(
                    '$notificationCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      label: 'Notification',
    );
  }

  void _onItemTapped(BuildContext context, int index) {
    setState(() {
      _currentIndex = index;
    });

    if (widget.userType == 'Admin') {
      switch (index) {
        case 0:
          _navigateWithFadeTransition(context, AdminHomePage());
          break;
        case 1:
          _navigateWithFadeTransition(
            context,
            UserManagementPage(
              userId: widget.userId,
              userType: widget.userType,
            ),
          );
          break;
        case 2:
          _showProfileDialog(context, widget.userId);
          break;
      }
    } else if (widget.userType == 'Seller') {
      switch (index) {
        case 0:
          _navigateWithFadeTransition(context, SellerHomePage());
          break;
        case 1:
          _navigateWithFadeTransition(
              context, SellerShopPage(userId: widget.userId));
          break;
        case 2:
          _navigateWithFadeTransition(
            context,
            ProductPage(
              userId: widget.userId,
              userType: widget.userType,
            ),
          );
          break;
        case 3:
          _showNotificationsDialog(context, widget.userId, widget.userType);
          break;
        case 4:
          _navigateWithFadeTransition(
            context,
            ChatListPage(
              userId: widget.userId,
              userType: widget.userType,
            ),
          );
          break;
        case 5:
          _showProfileDialog(context, widget.userId);
          break;
      }
    } else if (widget.userType == 'Buyer') {
      switch (index) {
        case 0:
          _navigateWithFadeTransition(context, BuyerHomePage());
          break;
        case 1:
          _navigateWithFadeTransition(context,
              ShopPage(userType: widget.userType, userId: widget.userId));
          break;
        case 2:
          _navigateWithFadeTransition(
              context, OrderProductsPage(userId: widget.userId));
          break;
        case 3:
          _showBuyerNotificationDialog(context, widget.userId);
          break;
        case 4:
          _navigateWithFadeTransition(
            context,
            ChatListPage(
              userId: widget.userId,
              userType: widget.userType,
            ),
          );
          break;
        case 5:
          _showProfileDialog(context, widget.userId);
          break;
      }
    }

    _fetchNotificationCount();
  }

  void _showProfileDialog(BuildContext context, String userId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Profile Dialog',
      pageBuilder: (context, _, __) => ProfilePage(userId: userId),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  void _showNotificationsDialog(
      BuildContext context, String userId, String userType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NotificationsDialog(
        userId: userId,
        userType: userType,
      ),
    );
  }

  void _showBuyerNotificationDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: BuyerNotificationDialog(userId: userId),
        );
      },
    );
  }

  void _navigateWithFadeTransition(BuildContext context, Widget page) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = 0.0;
          const end = 1.0;
          const curve = Curves.easeInOut;
          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          final fadeAnimation = animation.drive(tween);

          return FadeTransition(
            opacity: fadeAnimation,
            child: child,
          );
        },
      ),
    );
  }
}
