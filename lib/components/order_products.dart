import 'package:capstone/components/botton_navbar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'chatbox.dart';

class ProductPage extends StatefulWidget {
  final String userId;
  final String userType;

  const ProductPage({Key? key, required this.userId, required this.userType})
      : super(key: key);

  @override
  _ProductPageState createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  bool _isApproved = false;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _checkApprovalStatus();
  }

  Future<void> _checkApprovalStatus() async {
    try {
      final snapshot = await _databaseRef
          .child('users')
          .child(widget.userId)
          .child('userprofiles')
          .child('seller_approval')
          .get();
      if (snapshot.exists) {
        setState(() {
          _isApproved = snapshot.value == true;
        });
      }
    } catch (e) {
      print("Error checking approval status: $e");
    }
  }

  Future<void> _fetchOrders() async {
    try {
      final snapshot = await _databaseRef.child('checkouts').get();

      if (snapshot.exists) {
        List<Map<String, dynamic>> ordersList = [];
        for (var child in snapshot.children) {
          final orderData = Map<String, dynamic>.from(child.value as Map);
          if (orderData['seller_id'] == widget.userId) {
            orderData['order_id'] = child.key;

            String buyerId = orderData['user_id'];
            final buyerSnapshot = await _databaseRef
                .child('users')
                .child(buyerId)
                .child('userprofiles')
                .get();

            if (buyerSnapshot.exists) {
              Map<dynamic, dynamic> buyerProfile =
                  buyerSnapshot.value as Map<dynamic, dynamic>;
              String buyerName =
                  "${buyerProfile['first_name']} ${buyerProfile['middle_name']} ${buyerProfile['last_name']}";
              String contactNumber =
                  buyerProfile['contact_number'] ?? 'No contact number';

              orderData['buyer_name'] = buyerName;
              orderData['contact_number'] = contactNumber;
            } else {
              orderData['buyer_name'] = "Unknown Buyer";
              orderData['contact_number'] = "No contact number";
            }

            if (!orderData.containsKey('status')) {
              orderData['status'] = 'Pending';
            }

            ordersList.add(orderData);
          }
        }

        setState(() {
          _orders = ordersList;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching orders: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildOrderItem(Map<String, dynamic> order) {
    String statusLabel = order['received_img'] != null
        ? 'Order Complete'
        : (order['status'] ?? 'Pending');
    Color badgeColor = order['received_img'] != null
        ? Colors.blue.withOpacity(0.2)
        : (order['status'] == 'Processed'
            ? Colors.green.withOpacity(0.2)
            : Colors.orange.withOpacity(0.2));
    Color textColor = order['received_img'] != null
        ? Colors.blue[800]!
        : (order['status'] == 'Processed'
            ? Colors.green[800]!
            : Colors.orange[800]!);
    Color borderColor =
        order['received_img'] != null ? Colors.blue : Colors.transparent;

    return GestureDetector(
      onTap: () {
        _showOrderDetailsDialog(order);
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: borderColor,
            width: 2.0,
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.0),
                      color: Colors.grey[200],
                    ),
                    child: order['imageUrl'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: Image.network(
                              order['imageUrl'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.error,
                                    color: Colors.red);
                              },
                            ),
                          )
                        : const Icon(Icons.shopping_bag,
                            size: 40, color: Colors.grey),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order['product_name'] ?? 'Unnamed Product',
                          style: const TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          "Buyer: ${order['buyer_name']}",
                          style: const TextStyle(
                            fontSize: 14.0,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          "Contact: ${order['contact_number']}",
                          style: const TextStyle(
                            fontSize: 14.0,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 4.0),
                      Text(
                        "₱${order['price']}",
                        style: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.production_quantity_limits,
                          size: 18.0, color: Colors.orange),
                      const SizedBox(width: 4.0),
                      Text(
                        "Qty: ${order['quantity']}",
                        style: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Container(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16.0,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 4.0),
                          Flexible(
                            child: Text(
                              order['location'] ?? 'No Location Provided',
                              style: const TextStyle(
                                fontSize: 14.0,
                                color: Colors.black54,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_shipping,
                          size: 16.0,
                          color: Colors.teal,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          order['checkout_option'] ?? 'No Option',
                          style: const TextStyle(
                            fontSize: 14.0,
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16.0, color: Colors.blue),
                      const SizedBox(width: 4.0),
                      Text(
                        order['selected_date'] ?? 'No Date',
                        style: const TextStyle(
                          fontSize: 14.0,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4.0,
                      horizontal: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetailsDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.shopping_bag,
                              size: 48,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              order['product_name'] ?? 'Order Details',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      const Divider(thickness: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildOrderDetailRow(
                              const Icon(Icons.person,
                                  size: 20, color: Colors.redAccent),
                              "Buyer",
                              order['buyer_name'],
                              trailingIcon: Icons.chat_bubble_outline,
                              onTrailingIconPressed: () {
                                _openChatWithBuyer(
                                    order['user_id'], order['buyer_name']);
                              },
                            ),
                            const SizedBox(height: 10),
                            _buildOrderDetailRow(
                              const Icon(Icons.phone,
                                  size: 20, color: Colors.redAccent),
                              "Contact",
                              order['contact_number'],
                            ),
                            const SizedBox(height: 10),
                            _buildOrderDetailRow(
                              const Text(
                                "₱",
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent),
                              ),
                              "Price",
                              "₱${order['price']}",
                            ),
                            const SizedBox(height: 10),
                            _buildOrderDetailRow(
                              const Icon(Icons.production_quantity_limits,
                                  size: 20, color: Colors.redAccent),
                              "Quantity",
                              "${order['quantity']}",
                            ),
                            const SizedBox(height: 10),
                            _buildOrderDetailRow(
                              const Icon(Icons.location_on,
                                  size: 20, color: Colors.redAccent),
                              "Location",
                              order['location'],
                            ),
                            const SizedBox(height: 10),
                            _buildOrderDetailRow(
                              const Icon(Icons.calendar_today,
                                  size: 20, color: Colors.redAccent),
                              "Date",
                              order['selected_date'],
                            ),
                            const SizedBox(height: 10),
                            _buildOrderDetailRow(
                              const Icon(Icons.local_shipping,
                                  size: 20, color: Colors.redAccent),
                              "Checkout Option",
                              order['checkout_option'],
                            ),
                          ],
                        ),
                      ),
                      const Divider(thickness: 1),
                      if (order['received_img'] != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Received Image",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10.0),
                                child: Image.network(
                                  order['received_img'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.error,
                                        color: Colors.red);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (order['status'] != 'Processed' &&
                              order['received_img'] == null)
                            ElevatedButton(
                              onPressed: order['status'] == 'Denied'
                                  ? null
                                  : () {
                                      setState(() {
                                        order['status'] = 'Denied';
                                      });
                                      _denyOrder(order);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: order['status'] == 'Denied'
                                    ? Colors.grey
                                    : Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                              ),
                              child: Text(
                                order['status'] == 'Denied' ? "Denied" : "Deny",
                                style: TextStyle(
                                    color: order['status'] == 'Denied'
                                        ? Colors.white
                                        : null),
                              ),
                            ),
                          const SizedBox(width: 10),
                          if (order['status'] != 'Denied' &&
                              order['received_img'] == null)
                            ElevatedButton(
                              onPressed: order['status'] == 'Processed'
                                  ? null
                                  : () {
                                      setState(() {
                                        order['status'] = 'Processed';
                                      });
                                      _processOrder(order);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: order['status'] == 'Processed'
                                    ? Colors.grey
                                    : Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                              ),
                              child: Text(
                                order['status'] == 'Processed'
                                    ? "Processed"
                                    : "Process",
                                style: TextStyle(
                                    color: order['status'] == 'Processed'
                                        ? Colors.white
                                        : null),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _denyOrder(Map<String, dynamic> order) async {
    try {
      // Update the order status to 'Denied' in Firebase
      await _databaseRef
          .child('checkouts')
          .child(order['order_id'])
          .update({'status': 'Denied'});

      setState(() {
        order['status'] = 'Denied';
      });

      // Send SMS notification to the buyer
      await _sendDenySMSNotification(order);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order marked as denied.'),
          backgroundColor: Colors.red,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to deny order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendDenySMSNotification(Map<String, dynamic> order) async {
    // Format the SMS message with the buyer's name, location, and selected date
    String message =
        "Sorry, ${order['buyer_name']} has denied your meet-up process on "
        "${order['location']}, ${order['selected_date']}.";

    // Send the SMS using the provided contact number
    final response = await http.post(
      Uri.parse("https://api.semaphore.co/api/v4/messages"),
      body: {
        'apikey': '95ba3c534aa1a8b3dd67a83685b93d35',
        'number': order['contact_number'],
        'message': message,
        'sendername': 'Handimerce'
      },
    );

    if (response.statusCode == 200) {
      print("Deny SMS sent successfully to ${order['contact_number']}");
    } else {
      print('Error sending Deny SMS: ${response.body}');
    }
  }

  Widget _buildOrderDetailRow(Widget icon, String label, String value,
      {IconData? trailingIcon, VoidCallback? onTrailingIconPressed}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        icon, // This can now accept any widget, including Text or Icon
        const SizedBox(width: 8.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                  color: Colors.black54,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14.0,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trailingIcon != null && onTrailingIconPressed != null)
                    IconButton(
                      icon: Icon(trailingIcon,
                          color: Colors.blueAccent, size: 20),
                      onPressed: onTrailingIconPressed,
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _processOrder(Map<String, dynamic> order) async {
    try {
      await _databaseRef
          .child('checkouts')
          .child(order['order_id'])
          .update({'status': 'Processed'});

      setState(() {
        order['status'] = 'Processed';
      });

      // Send SMS notification to the buyer
      _sendSMSNotification(order);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order marked as processed.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendSMSNotification(Map<String, dynamic> order) async {
    String message =
        "${order['buyer_name']} is already processing your product. "
        "Prepare at ${order['location']}, ${order['selected_date']} for ${order['checkout_option']}.";

    final response = await http.post(
      Uri.parse("https://api.semaphore.co/api/v4/messages"),
      body: {
        'apikey': '95ba3c534aa1a8b3dd67a83685b93d35',
        'number': order['contact_number'],
        'message': message,
        'sendername': 'Handimerce'
      },
    );

    if (response.statusCode == 200) {
      print("SMS sent successfully to ${order['contact_number']}");
    } else {
      print('Error sending SMS: ${response.body}');
    }
  }

  void _openChatWithBuyer(String buyerId, String buyerName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          userId: widget.userId,
          userType: widget.userType,
          recipientId: buyerId,
          recipientName: buyerName,
          onRecipientChange: (newRecipientId) {
            // Handle recipient change if required
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Orders"),
          backgroundColor: Colors.red[900],
        ),
        body: Stack(
          children: [
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? const Center(child: Text("No orders found."))
                    : ListView.builder(
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          return _buildOrderItem(_orders[index]);
                        },
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
        bottomNavigationBar: BottomNavBar(
          userId: widget.userId,
          userType: widget.userType,
          selectedIndex: 2,
        ),
      ),
    );
  }
}
