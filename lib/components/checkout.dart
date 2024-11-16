import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:capstone/components/shop.dart';

class CheckoutPage extends StatefulWidget {
  final double totalPrice;
  final List<Map<String, dynamic>> cartItems;
  final String sellerId;

  const CheckoutPage({
    super.key,
    required this.totalPrice,
    required this.cartItems,
    required this.sellerId,
  });

  @override
  _CheckoutPageState createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String? _selectedOption = 'Pick Up';
  DateTime? _selectedDate;
  String _sellerAddress = '';
  String _sellerContactNumber = '';
  String _buyerFullName = '';
  final TextEditingController _locationController = TextEditingController();
  bool _isMeetUpDisabled = false;

  @override
  void initState() {
    super.initState();
    _fetchSellerAddress();
  }

  void _fetchSellerAddress() async {
    try {
      final DatabaseReference userRef = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(widget.sellerId)
          .child('userprofiles');

      DatabaseEvent snapshot = await userRef.once();
      if (snapshot.snapshot.exists) {
        Map<dynamic, dynamic> userProfile =
            snapshot.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _sellerAddress = userProfile['address'] ?? 'No address available';
          _sellerContactNumber =
              userProfile['contact_number'] ?? 'No contact number';
          _locationController.text = _sellerAddress;
        });
      }
    } catch (e) {
      print('Error fetching seller details: $e');
    }
  }

  Future<void> _fetchUserFullName(String userId) async {
    try {
      final DatabaseReference userRef = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(userId)
          .child('userprofiles');

      DatabaseEvent snapshot = await userRef.once();
      if (snapshot.snapshot.exists) {
        Map<dynamic, dynamic> userProfile =
            snapshot.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          String firstName = userProfile['first_name'] ?? '';
          String middleName = userProfile['middle_name'] ?? '';
          String lastName = userProfile['last_name'] ?? '';
          _buyerFullName =
              '$firstName ${middleName.isNotEmpty ? '$middleName ' : ''}$lastName'
                  .trim();
        });
      }
    } catch (e) {
      print('Error fetching user details: $e');
    }
  }

  Future<void> _confirmCheckout() async {
    if (_selectedOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an option.')),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date.')),
      );
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    final String? userId = user?.uid;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to proceed.')),
      );
      return;
    }

    await _fetchUserFullName(userId);

    final String location = _selectedOption == 'Pick Up'
        ? _sellerAddress
        : _locationController.text;

    if (_selectedOption == 'Meet Up' && location.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location for Meet Up.')),
      );
      return;
    }

    List<String> checkoutDetails = [];

    for (final item in widget.cartItems) {
      try {
        final DatabaseReference checkoutRef = FirebaseDatabase.instance
            .ref()
            .child('checkouts')
            .child(item['id']);

        String formattedDate = DateFormat.yMMMMd().format(_selectedDate!);
        await checkoutRef.set({
          'product_id': item['id'],
          'product_name': item['name'],
          'price': item['price'],
          'quantity': item['quantity'],
          'seller_id': widget.sellerId,
          'user_id': userId,
          'checkout_option': _selectedOption,
          'selected_date': formattedDate,
          'location': location,
          'imageUrl': item['imageUrl'],
          'notification_read': false,
        });

        checkoutDetails.add("${item['name']} x${item['quantity']}");

        final DatabaseReference cartRef = FirebaseDatabase.instance
            .ref()
            .child('shoppingCart')
            .child(userId)
            .child(item['id']);

        await cartRef.remove();
      } catch (e) {
        print('Error during checkout: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error during checkout. Please try again.')),
        );
        return;
      }
    }

    String message = "$_buyerFullName has checked out the following items:\n";
    for (final detail in checkoutDetails) {
      message += "$detail\n";
    }
    message += "Expected on: ${DateFormat.yMMMMd().format(_selectedDate!)}";

    final response = await http.post(
      Uri.parse("https://api.semaphore.co/api/v4/messages"),
      body: {
        'apikey': '95ba3c534aa1a8b3dd67a83685b93d35',
        'number': _sellerContactNumber,
        'message': message,
        'sendername': 'Handimerce'
      },
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Checkout successful for $_selectedOption on ${DateFormat.yMMMMd().format(_selectedDate!)}.',
          ),
        ),
      );
    } else {
      print('Error sending SMS: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send SMS notification.')),
      );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ShopPage(userId: userId, userType: 'Buyer'),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;

        // Disable "Meet Up" option for March 1-30 and August 1-30
        _isMeetUpDisabled = (pickedDate.month == 3 && pickedDate.day <= 30) ||
            (pickedDate.month == 8 && pickedDate.day <= 30);

        if (_isMeetUpDisabled && _selectedOption == 'Meet Up') {
          _selectedOption = 'Pick Up';
          _locationController.text = _sellerAddress;
        }
      });
    }
  }

  void _showMeetUpDisabledDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Meet Up Unavailable Due to an Event'),
          content: const Text(
            ' .',
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout Options'),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Products:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: widget.cartItems.length,
                itemBuilder: (context, index) {
                  final item = widget.cartItems[index];
                  double itemPrice =
                      double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                  int itemQuantity =
                      int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
                  double totalPrice = itemPrice * itemQuantity;

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (item['imageUrl'] != null &&
                              item['imageUrl'].isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item['imageUrl'],
                                fit: BoxFit.cover,
                                width: 60,
                                height: 60,
                              ),
                            )
                          else
                            const Icon(Icons.shopping_bag,
                                size: 60, color: Colors.grey),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] ?? 'Unnamed Product',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Quantity: $itemQuantity',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₱${totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose an Option:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Pick Up'),
                    value: 'Pick Up',
                    groupValue: _selectedOption,
                    onChanged: (value) {
                      setState(() {
                        _selectedOption = value;
                        _locationController.text = _sellerAddress;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_isMeetUpDisabled) {
                        _showMeetUpDisabledDialog();
                      } else {
                        setState(() {
                          _selectedOption = 'Meet Up';
                          _locationController.clear();
                        });
                      }
                    },
                    child: AbsorbPointer(
                      absorbing:
                          _isMeetUpDisabled, // Prevent selection when disabled
                      child: RadioListTile<String>(
                        title: const Text('Meet Up'),
                        value: 'Meet Up',
                        groupValue: _selectedOption,
                        onChanged: (value) {
                          setState(() {
                            _selectedOption = value;
                            _locationController.clear();
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: _selectedOption == 'Pick Up'
                    ? _sellerAddress
                    : 'Enter location',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              readOnly: _selectedOption == 'Pick Up',
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _pickDate(context),
              child: AbsorbPointer(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: _selectedDate == null
                        ? 'Select Date'
                        : DateFormat.yMMMMd().format(_selectedDate!),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _confirmCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Confirm',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
