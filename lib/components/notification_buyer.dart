import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class BuyerNotificationDialog extends StatefulWidget {
  final String userId;

  const BuyerNotificationDialog({super.key, required this.userId});

  @override
  _BuyerNotificationDialogState createState() =>
      _BuyerNotificationDialogState();
}

class _BuyerNotificationDialogState extends State<BuyerNotificationDialog> {
  final _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final snapshot = await _database.child('checkouts').get();
    if (snapshot.exists) {
      final checkoutsData = snapshot.value as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> loadedNotifications = [];

      for (var key in checkoutsData.keys) {
        final checkout = checkoutsData[key] as Map<dynamic, dynamic>;

        // Filter notifications where `user_id` matches the logged-in user's ID and status is 'Processed'
        if (checkout['user_id'] == widget.userId &&
            checkout['status'] == 'Processed') {
          // Fetch the seller's name asynchronously
          String sellerFullName = await _fetchSellerName(checkout['seller_id']);

          loadedNotifications.add({
            'id': key,
            'sellerId': checkout['seller_id'] ?? 'Unknown Seller',
            'sellerName': sellerFullName,
            'productName': checkout['product_name'] ?? 'Unnamed Product',
            'quantity': checkout['quantity'] ?? 0,
            'status': checkout['status'] ?? 'Pending',
            'timestamp': checkout['selected_date'] ?? '',
            'isRead': checkout['notification_read_buyers'] ?? false,
            'receivedImg': checkout['received_img'],
            'checkoutOption': checkout['checkout_option'] ?? 'N/A',
          });
        }
      }

      // Sort notifications by timestamp, most recent first
      loadedNotifications
          .sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

      setState(() {
        _notifications = loadedNotifications;
      });

      // Mark all notifications as read
      _markAllNotificationsAsRead();
    }
  }

  Future<String> _fetchSellerName(String sellerId) async {
    final sellerSnapshot =
        await _database.child('users/$sellerId/userprofiles').get();
    if (sellerSnapshot.exists) {
      final sellerData = sellerSnapshot.value as Map<dynamic, dynamic>;
      final firstName = sellerData['first_name'] ?? '';
      final lastName = sellerData['last_name'] ?? '';
      final middleName = sellerData['middle_name'] ?? '';
      return '$firstName $middleName $lastName';
    }
    return 'Unknown Seller';
  }

  void _markAllNotificationsAsRead() {
    for (var notification in _notifications) {
      if (!notification['isRead']) {
        _database
            .child('checkouts/${notification['id']}')
            .update({'notification_read_buyers': true});
      }
    }
  }

  void _dismissNotification(String notificationId) async {
    // Update `notification_display` to `true` for this notification in Firebase
    await _database
        .child('checkouts/$notificationId')
        .update({'notification_display': true});

    // Remove the notification from the displayed list
    setState(() {
      _notifications
          .removeWhere((notification) => notification['id'] == notificationId);
    });
  }

  String _formatTimestamp(String timestamp) {
    try {
      final date = DateFormat("MMMM d, yyyy").parse(timestamp);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with red background and left-aligned icon and text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.red[900],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.notifications, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    "Notifications",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _notifications.isEmpty
                    ? const Center(child: Text("No notifications available"))
                    : ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          return Card(
                            color: notification['isRead']
                                ? Colors.white
                                : Colors.red[50], // Light red for unread
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor:
                                                  notification['isRead']
                                                      ? Colors.grey[300]
                                                      : Colors.red[900],
                                              radius: 15,
                                              child: const Icon(
                                                Icons.notifications,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                "${notification['productName']}",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // "X" button to dismiss the notification
                                      IconButton(
                                        icon: const Icon(Icons.close,
                                            color: Colors.grey),
                                        onPressed: () => _dismissNotification(
                                            notification['id']),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // New line for "Prepare Checkout Option"
                                  Text.rich(
                                    TextSpan(
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700]),
                                      children: [
                                        TextSpan(
                                          text: "${notification['sellerName']}",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87),
                                        ),
                                        const TextSpan(
                                          text: " has processed your order ",
                                        ),
                                        TextSpan(
                                          text:
                                              "${notification['productName']}",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87),
                                        ),
                                        const TextSpan(
                                          text: ". Prepare ",
                                        ),
                                        TextSpan(
                                          text:
                                              "${notification['checkoutOption']}",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87),
                                        ),
                                        const TextSpan(
                                          text: " on this date: ",
                                        ),
                                        TextSpan(
                                          text: _formatTimestamp(
                                              notification['timestamp']),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (notification['receivedImg'] != null) ...[
                                    const SizedBox(height: 12),
                                    const Divider(height: 20, thickness: 1),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle,
                                            color: Colors.green, size: 20),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            "${notification['productName']} has been successfully received.",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.green[700],
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        notification['receivedImg'],
                                        height: 150,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 10),
            // Close button with red background
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: Colors.red[900],
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                "Close",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
