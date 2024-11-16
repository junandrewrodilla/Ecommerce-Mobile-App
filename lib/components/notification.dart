import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class NotificationsDialog extends StatefulWidget {
  final String userId;
  final String userType;

  const NotificationsDialog({
    super.key,
    required this.userId,
    required this.userType,
  });

  @override
  _NotificationsDialogState createState() => _NotificationsDialogState();
}

class _NotificationsDialogState extends State<NotificationsDialog> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  void _fetchNotifications() async {
    final shopProductsRef =
        _database.ref().child('shops').child(widget.userId).child('products');
    final checkoutsRef = _database.ref().child('checkouts');
    final usersRef = _database.ref().child('users');

    final event = await checkoutsRef.get();
    final checkoutsData = event.value as Map<dynamic, dynamic>?;

    if (checkoutsData != null) {
      List<Map<String, dynamic>> newNotifications = [];

      for (var checkoutId in checkoutsData.keys) {
        var checkoutValue = checkoutsData[checkoutId] as Map<dynamic, dynamic>;

        // Only proceed if `seller_id` matches the logged-in user's ID
        if (checkoutValue['seller_id'] != widget.userId) {
          continue;
        }

        if (checkoutValue['notification_display_seller'] == true) {
          continue;
        }

        final productId = checkoutValue['product_id'];
        final userId = checkoutValue['user_id'];
        final productSnapshot = await shopProductsRef.child(productId).get();

        if (productSnapshot.exists) {
          final userSnapshot =
              await usersRef.child(userId).child('userprofiles').get();
          if (userSnapshot.exists) {
            final userData = userSnapshot.value as Map<dynamic, dynamic>?;

            newNotifications.add({
              'productId': productId,
              'productName': checkoutValue['product_name'],
              'quantity': checkoutValue['quantity'],
              'selectedDate': checkoutValue['selected_date'],
              'firstName': userData?['first_name'] ?? 'N/A',
              'lastName': userData?['last_name'] ?? 'N/A',
              'middleName': userData?['middle_name'] ?? 'N/A',
              'receivedImg': checkoutValue['received_img'],
              'checkoutId': checkoutId,
              'contactNumber': userData?['contact_number'] ?? '',
            });
          }
        }
      }

      setState(() {
        _notifications = newNotifications;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _dismissNotification(String checkoutId) async {
    await _database.ref().child('checkouts/$checkoutId').update({
      'notification_display_seller': true,
    });

    setState(() {
      _notifications.removeWhere(
          (notification) => notification['checkoutId'] == checkoutId);
    });
  }

  Future<void> _markAllNotificationsAsRead() async {
    for (var notification in _notifications) {
      final String checkoutId = notification['checkoutId'];
      await _database.ref().child('checkouts/$checkoutId').update({
        'notification_read': true,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevents back button dismissal
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[700],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.notifications,
                            color: Colors.white, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '(${_notifications.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    )
                  : _notifications.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No notifications available',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : SizedBox(
                          height: 300,
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _notifications.length,
                            itemBuilder: (context, index) {
                              final notification = _notifications[index];
                              return _buildNotificationCard(notification);
                            },
                          ),
                        ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton(
                  onPressed: () async {
                    await _markAllNotificationsAsRead();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24),
                  ),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    String buyerFullName =
        '${notification['firstName']} ${notification['middleName']} ${notification['lastName']}';
    String productDescription =
        "${notification['productName']} (${notification['quantity']} pcs)";
    String message =
        "$buyerFullName has purchased $productDescription and requested to pick up the order on ${notification['selectedDate']}.";

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Product: ${notification['productName'] ?? 'No Product Name'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () =>
                      _dismissNotification(notification['checkoutId']),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            if (notification['receivedImg'] != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 20, thickness: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "${notification['productName']} has been successfully received by $buyerFullName.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 1.5,
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                    image: DecorationImage(
                      image: NetworkImage(notification['receivedImg']),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
