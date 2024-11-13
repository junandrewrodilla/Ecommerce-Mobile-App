import 'package:capstone/components/chatbox.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:capstone/components/botton_navbar.dart';
import 'package:capstone/components/navbar.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';

class OrderProductsPage extends StatefulWidget {
  final String userId;

  const OrderProductsPage({Key? key, required this.userId}) : super(key: key);

  @override
  _OrderProductsPageState createState() => _OrderProductsPageState();
}

class _OrderProductsPageState extends State<OrderProductsPage> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      final snapshot = await _databaseRef.child('checkouts').get();

      if (snapshot.exists) {
        List<Map<String, dynamic>> ordersList = [];
        for (var child in snapshot.children) {
          final orderData = Map<String, dynamic>.from(child.value as Map);
          if (orderData['user_id'] == widget.userId) {
            orderData['order_id'] = child.key;

            // Fetch seller's name based on seller_id
            if (orderData['seller_id'] != null) {
              final sellerSnapshot = await _databaseRef
                  .child('users')
                  .child(orderData['seller_id'])
                  .child('userprofiles')
                  .get();

              if (sellerSnapshot.exists) {
                final sellerProfile =
                    Map<String, dynamic>.from(sellerSnapshot.value as Map);
                final firstName = sellerProfile['first_name'] ?? '';
                final middleName = sellerProfile['middle_name'] ?? '';
                final lastName = sellerProfile['last_name'] ?? '';

                final sellerFullName =
                    "$firstName $middleName $lastName".trim();
                orderData['seller_name'] = sellerFullName;
              } else {
                orderData['seller_name'] = 'Unknown Seller';
              }
            } else {
              orderData['seller_name'] = 'No Seller Info';
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
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => ProductDetailsDialog(order: order),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
          side: BorderSide(
            color: order['status'] == 'Processed'
                ? Colors.lightGreen
                : (order['status'] == 'Denied'
                    ? Colors.red
                    : Colors.transparent),
            width: 2.0,
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.0),
                      color: Colors.grey[300],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
                ],
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
                    const SizedBox(height: 6.0),
                    Row(
                      children: [
                        const SizedBox(width: 4.0),
                        Text(
                          "₱${order['price']}",
                          style: const TextStyle(
                            fontSize: 15.0,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        Icon(Icons.production_quantity_limits,
                            size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 4.0),
                        Text(
                          "Qty: ${order['quantity']}",
                          style: const TextStyle(
                            fontSize: 15.0,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, thickness: 1.0),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 16, color: Colors.red[700]),
                        const SizedBox(width: 4.0),
                        Expanded(
                          child: Text(
                            order['location'] ?? 'No Location Provided',
                            style: const TextStyle(
                              fontSize: 12.0,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6.0),
                    Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.purple[700]),
                        const SizedBox(width: 4.0),
                        Expanded(
                          child: Text(
                            order['seller_name'] ?? 'Unknown Seller',
                            style: const TextStyle(
                              fontSize: 12.0,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6.0),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: Colors.blue[700]),
                        const SizedBox(width: 4.0),
                        Text(
                          order['selected_date'] ?? 'No Date',
                          style: const TextStyle(
                            fontSize: 12.0,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6.0),
                    Row(
                      children: [
                        Icon(Icons.local_shipping,
                            size: 14, color: Colors.teal[700]),
                        const SizedBox(width: 4.0),
                        Text(
                          order['checkout_option'] ?? 'No Option',
                          style: const TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String userType = 'Buyer';

    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        body: Column(
          children: [
            Navbar(
              userId: widget.userId,
              userType: userType,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _orders.isEmpty
                      ? const Center(child: Text("No orders found."))
                      : ListView.builder(
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            return _buildOrderItem(_orders[index]);
                          },
                        ),
            ),
          ],
        ),
        bottomNavigationBar: kIsWeb
            ? null // Hide BottomNavBar on web platform
            : BottomNavBar(
                userId: widget.userId,
                userType: userType,
                selectedIndex: 2,
              ),
      ),
    );
  }
}

class ProductDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> order;

  const ProductDetailsDialog({Key? key, required this.order}) : super(key: key);

  @override
  _ProductDetailsDialogState createState() => _ProductDetailsDialogState();
}

class _ProductDetailsDialogState extends State<ProductDetailsDialog> {
  File? _pickedImage;
  bool _isReceived = false;
  bool _isUploading = false;
  String? _sellerContactNumber;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _checkIfReceived();
    _fetchSellerContact();
  }

  void _checkIfReceived() {
    if (widget.order['received_img'] != null) {
      setState(() {
        _isReceived = true;
      });
    }
  }

  Future<void> _fetchSellerContact() async {
    if (widget.order['seller_contact_number'] != null) {
      setState(() {
        _sellerContactNumber = widget.order['seller_contact_number'];
      });
    } else if (widget.order['seller_id'] != null) {
      final sellerData = await _databaseRef
          .child('users')
          .child(widget.order['seller_id'])
          .child('userprofiles')
          .child('contact_number')
          .get();

      if (sellerData.exists) {
        setState(() {
          _sellerContactNumber = sellerData.value.toString();
        });
      } else {
        print('Seller contact number not available.');
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
      });
      await _uploadImageToFirebase(File(image.path));
    }
  }

  Future<void> _uploadImageToFirebase(File image) async {
    try {
      setState(() {
        _isUploading = true;
      });

      final storageRef = FirebaseStorage.instance.ref().child(
          'received_images/${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = storageRef.putFile(image);
      final snapshot = await uploadTask;

      if (snapshot.state == TaskState.success) {
        final downloadUrl = await snapshot.ref.getDownloadURL();

        final orderId = widget.order['order_id'] as String?;
        if (orderId == null) {
          print("Error: order_id is missing.");
          return;
        }

        await _databaseRef.child('checkouts').child(orderId).update({
          'received_img': downloadUrl,
          'notification_read': false,
        });

        setState(() {
          _isReceived = true;
          widget.order['received_img'] = downloadUrl;
        });

        final buyerName = widget.order['buyer_name'] ?? 'Buyer';
        final productName = widget.order['product_name'] ?? 'Product';

        if (_sellerContactNumber != null) {
          await _sendSMSNotificationToSeller(
            sellerNumber: _sellerContactNumber!,
            buyerName: buyerName,
            productName: productName,
          );
        } else {
          print("No seller contact number available.");
        }

        // Subtract quantity from stock and add to total_sold
        final String productId = widget.order['product_id'];
        final int quantity = widget.order['quantity'];
        await _subtractProductStocks(productId, quantity);
      }
    } catch (e) {
      print('Error uploading image: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _sendSMSNotificationToSeller({
    required String sellerNumber,
    required String buyerName,
    required String productName,
  }) async {
    String message = "$buyerName has received your product ($productName).";

    final response = await http.post(
      Uri.parse("https://api.semaphore.co/api/v4/messages"),
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: {
        'apikey': '95ba3c534aa1a8b3dd67a83685b93d35',
        'number': sellerNumber,
        'message': message,
        'sendername': 'Handimerce'
      },
    );

    if (response.statusCode == 200) {
      print("SMS sent successfully to seller at $sellerNumber");
    } else {
      print('Error sending SMS: ${response.body}');
    }
  }

  Future<void> _subtractProductStocks(
      String productId, int checkoutQuantity) async {
    try {
      final shopsSnapshot = await _databaseRef.child('shops').get();
      if (shopsSnapshot.exists) {
        for (var shop in shopsSnapshot.children) {
          // Access stocks and total_sold directly under each product node in private shops
          var privateProductRef = shop.child('products').child(productId);

          if (privateProductRef.exists) {
            // Subtract stocks
            int currentPrivateStocks = int.tryParse(
                    privateProductRef.child('stocks').value.toString()) ??
                0;
            int newPrivateStocks = currentPrivateStocks - checkoutQuantity;
            newPrivateStocks = newPrivateStocks < 0 ? 0 : newPrivateStocks;

            // Update stocks in the database
            await _databaseRef
                .child('shops')
                .child(shop.key!)
                .child('products')
                .child(productId)
                .update({'stocks': newPrivateStocks.toString()});

            // Update total_sold in the database
            int currentPrivateSold = int.tryParse(
                    privateProductRef.child('total_sold').value.toString()) ??
                0;
            int newPrivateSold = currentPrivateSold + checkoutQuantity;

            await _databaseRef
                .child('shops')
                .child(shop.key!)
                .child('products')
                .child(productId)
                .update({'total_sold': newPrivateSold.toString()});
          }
        }

        // Update public shop's product stocks and total_sold directly under the product node
        var publicProductRef =
            _databaseRef.child('shops').child('public_shops').child(productId);

        final publicProductSnapshot = await publicProductRef.get();
        if (publicProductSnapshot.exists) {
          int currentPublicStocks = int.tryParse(
                  publicProductSnapshot.child('stocks').value.toString()) ??
              0;
          int newPublicStocks = currentPublicStocks - checkoutQuantity;
          newPublicStocks = newPublicStocks < 0 ? 0 : newPublicStocks;

          int currentPublicSold = int.tryParse(
                  publicProductSnapshot.child('total_sold').value.toString()) ??
              0;
          int newPublicSold = currentPublicSold + checkoutQuantity;

          // Update stocks and total_sold in a single update call
          await publicProductRef.update({
            'stocks': newPublicStocks.toString(),
            'total_sold': newPublicSold.toString(),
          });
        }
      }
    } catch (e) {
      print('Error updating stocks and total sold: $e');
    }
  }

  Future<void> _changeLocation() async {
    String newLocation = widget.order['location'] ?? '';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Location'),
          content: TextField(
            decoration: const InputDecoration(hintText: "Enter new location"),
            onChanged: (value) {
              newLocation = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                await _databaseRef
                    .child('checkouts')
                    .child(widget.order['order_id'])
                    .update({'location': newLocation});

                setState(() {
                  widget.order['location'] = newLocation;
                });

                Navigator.of(context).pop();
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _openChatWithSeller() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          userId: widget.order['user_id'],
          userType: 'Buyer',
          recipientId: widget.order['seller_id'],
          recipientName: widget.order['seller_name'] ?? 'Unknown Seller',
          onRecipientChange: (newRecipientId) {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isOrderProcessed = widget.order['status'] == "Processed";
    final bool isOrderDenied = widget.order['status'] == "Denied";

    return Stack(
      children: [
        Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isOrderDenied)
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: Colors.red),
                            ),
                            child: const Text(
                              "Seller has denied your order.",
                              style: TextStyle(
                                fontSize: 14.0,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          ElevatedButton(
                            onPressed: _changeLocation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 10.0),
                            ),
                            child: const Text(
                              "Change Location",
                              style: TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20.0),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: widget.order['imageUrl'] != null
                          ? Image.network(
                              widget.order['imageUrl'],
                              fit: BoxFit.cover,
                              height: 200,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.error,
                                    color: Colors.red, size: 100);
                              },
                            )
                          : const Icon(Icons.shopping_bag,
                              size: 100, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  Text(
                    widget.order['product_name'] ?? 'Unnamed Product',
                    style: const TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  _buildDetailRow(
                    label: "Price",
                    value: "₱${widget.order['price']}",
                  ),
                  _buildDetailRow(
                    icon: Icons.production_quantity_limits,
                    label: "Quantity",
                    value: "${widget.order['quantity']}",
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        icon: Icons.person,
                        label: "Seller",
                        value: widget.order['seller_name'] ?? 'Unknown Seller',
                        trailingWidget: IconButton(
                          iconSize: 20,
                          icon: Icon(Icons.chat_bubble_outline,
                              color: Colors.teal),
                          onPressed: _openChatWithSeller,
                        ),
                      ),
                      if (_sellerContactNumber != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 28.0, top: 4.0),
                          child: Text(
                            ": $_sellerContactNumber",
                            style: const TextStyle(
                              fontSize: 13.0,
                              color: Color.fromARGB(137, 255, 255, 255),
                            ),
                          ),
                        ),
                    ],
                  ),
                  _buildDetailRow(
                    icon: Icons.location_on,
                    label: "Location",
                    value: widget.order['location'] ?? 'No Location Provided',
                  ),
                  const SizedBox(height: 5),
                  _buildDetailRow(
                    icon: Icons.calendar_today,
                    label: "Selected Date",
                    value: widget.order['selected_date'] ?? 'No Date',
                  ),
                  const SizedBox(height: 5),
                  _buildDetailRow(
                    icon: Icons.local_shipping,
                    label: "Checkout Option",
                    value: widget.order['checkout_option'] ?? 'No Option',
                  ),
                  const SizedBox(height: 20.0),
                  if (widget.order['received_img'] != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: Image.network(
                            widget.order['received_img'],
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.error,
                                  color: Colors.red, size: 100);
                            },
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        const Center(
                          child: Text(
                            "Order Received Image",
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20.0),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isOrderProcessed)
                          ElevatedButton(
                            onPressed:
                                _isReceived || _isUploading ? null : _pickImage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isReceived ? Colors.grey : Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 10.0),
                            ),
                            child: Text(
                              _isReceived ? "Order Received" : "Receive",
                              style: const TextStyle(
                                  fontSize: 14.0, fontWeight: FontWeight.bold),
                            ),
                          ),
                        if (isOrderProcessed) const SizedBox(width: 8.0),
                        ElevatedButton(
                          onPressed: _isUploading
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                },
                          style: ElevatedButton.styleFrom(
                            primary: Colors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 10.0),
                          ),
                          child: const Text(
                            "Close",
                            style: TextStyle(
                                fontSize: 14.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isUploading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDetailRow({
    IconData? icon,
    required String label,
    required String value,
    Widget? trailingWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          if (icon != null)
            Icon(icon, size: 20, color: Colors.teal)
          else
            Text(
              "₱",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          const SizedBox(width: 8.0),
          Text(
            "$label: ",
            style: const TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.0,
                color: Colors.black54,
              ),
            ),
          ),
          if (trailingWidget != null) trailingWidget,
        ],
      ),
    );
  }
}
