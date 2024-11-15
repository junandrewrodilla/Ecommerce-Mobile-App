import 'package:capstone/components/botton_navbar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../home/admin_page.dart';

class User {
  final String uid;
  final String firstName;
  final String lastName;
  final String middleName;
  final String userType;
  final String address;
  final String email;
  final bool sellerApproval;
  final bool isDeactivated;
  final String validIdUrl;
  final String certificateUrl;

  User({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.middleName,
    required this.userType,
    required this.address,
    required this.email,
    required this.sellerApproval,
    required this.isDeactivated,
    required this.validIdUrl,
    required this.certificateUrl,
  });

  factory User.fromMap(String uid, Map<dynamic, dynamic> data) {
    return User(
      uid: uid,
      firstName: data['first_name'] ?? 'N/A',
      lastName: data['last_name'] ?? 'N/A',
      middleName: data['middle_name'] ?? 'N/A',
      userType: data['user_type'] ?? 'N/A',
      address: data['address'] ?? 'N/A',
      email: data['email'] ?? 'N/A',
      sellerApproval: data['seller_approval'] ?? false,
      isDeactivated: data['Deactivate'] ?? false,
      validIdUrl: data['valid_id_url'] ?? '',
      certificateUrl: data['certificate_url'] ?? '',
    );
  }
}

class UserManagementPage extends StatefulWidget {
  final String userId;
  final String userType;

  UserManagementPage({required this.userId, required this.userType});

  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final DatabaseReference _databaseReference =
      FirebaseDatabase.instance.ref().child('users');
  List<User> _users = [];
  List<User> _filteredUsers = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  void _fetchUsers() async {
    try {
      _databaseReference.once().then((snapshot) {
        List<User> usersList = [];
        if (snapshot.snapshot.value != null) {
          Map<dynamic, dynamic> usersData =
              snapshot.snapshot.value as Map<dynamic, dynamic>;
          usersData.forEach((key, value) {
            if (value['userprofiles'] != null) {
              User user = User.fromMap(key, value['userprofiles']);
              if (user.userType != 'Admin') {
                usersList.add(user);
              }
            }
          });
        }
        setState(() {
          _users = usersList;
          _filteredUsers = usersList;
          _isLoading = false;
        });
      }).catchError((error) {
        print('Error fetching users: $error');
        setState(() {
          _isLoading = false;
        });
      });
    } catch (e) {
      print('Error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterUsers(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<User> filteredList = _users;

    if (_selectedFilter != 'All') {
      filteredList = filteredList
          .where((user) =>
              user.userType.toLowerCase() == _selectedFilter.toLowerCase())
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      filteredList = filteredList.where((user) {
        final fullName =
            '${user.firstName.toLowerCase()} ${user.middleName.toLowerCase()} ${user.lastName.toLowerCase()}';
        return fullName.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    setState(() {
      _filteredUsers = filteredList;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _approveSeller(String userId) async {
    DatabaseReference userRef =
        _databaseReference.child(userId).child('userprofiles');
    await userRef.update({'seller_approval': true});
    _fetchUsers();
  }

  void _declineSeller(String userId) async {
    DatabaseReference userRef =
        _databaseReference.child(userId).child('userprofiles');
    await userRef.update({'seller_approval': false});
    _fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    // Determine whether the app is running on a web/desktop layout
    bool isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.red[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    AdminHomePage(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 100),
              ),
            );
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Search by Name',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0)),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      const Text('Filter by:', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: _selectedFilter,
                        items: <String>['All', 'Seller', 'Buyer']
                            .map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value,
                                style:
                                    const TextStyle(color: Color(0xFF8B0000))),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            _filterUsers(newValue);
                          }
                        },
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B0000)),
                        iconEnabledColor: const Color(0xFF8B0000),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        Color? borderColor;
                        if (user.userType == 'Seller') {
                          borderColor =
                              user.sellerApproval ? Colors.green : Colors.red;
                        }
                        return GestureDetector(
                          onTap: () => _showUserDetails(user),
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: borderColor != null
                                  ? BorderSide(color: borderColor, width: 2.0)
                                  : BorderSide.none,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '${user.firstName} ${user.middleName} ${user.lastName}',
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(user.email,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey)),
                                        const SizedBox(height: 4),
                                        Text('Address: ${user.address}',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey)),
                                        const SizedBox(height: 4),
                                        Text('Type: ${user.userType}',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  if (user.isDeactivated)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: Colors.grey,
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: const Text(
                                            'This account is Deactivated',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white)),
                                      ),
                                    ),
                                  if (user.userType == 'Seller' &&
                                      !user.isDeactivated)
                                    Row(
                                      children: [
                                        IconButton(
                                            icon: const Icon(Icons.check_circle,
                                                color: Colors.green),
                                            onPressed: () =>
                                                _approveSeller(user.uid)),
                                        IconButton(
                                            icon: const Icon(Icons.cancel,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _declineSeller(user.uid)),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: isWeb
          ? null
          : BottomNavBar(
              userId: widget.userId,
              userType: widget.userType,
              selectedIndex: 1, // Adjust this index if necessary
            ),
    );
  }

  void _showUserDetails(User user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.person, color: Colors.blue),
              const SizedBox(width: 8),
              Text('${user.firstName} ${user.lastName}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  const Icon(Icons.badge, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text('User Type: ${user.userType}',
                      style: const TextStyle(fontSize: 16)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.email, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Email: ${user.email}',
                        style: const TextStyle(fontSize: 16)),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.location_on, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Address: ${user.address}',
                        style: const TextStyle(fontSize: 16)),
                  ),
                ]),
                const Divider(height: 20, thickness: 1),
                const Text('Valid ID:',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                user.validIdUrl.isNotEmpty
                    ? GestureDetector(
                        onTap: () =>
                            _showImageOverlay(user.validIdUrl, "Valid ID"),
                        child: Image.network(user.validIdUrl,
                            height: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Text('Failed to load Valid ID image')),
                      )
                    : const Column(children: [
                        Icon(Icons.image_not_supported,
                            color: Colors.grey, size: 50),
                        Text('No Valid ID image available',
                            style: TextStyle(color: Colors.grey))
                      ]),
                if (user.userType != 'Buyer') ...[
                  const Divider(height: 20, thickness: 1),
                  const Text('Certificate:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  user.certificateUrl.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _showImageOverlay(
                              user.certificateUrl, "Certificate"),
                          child: Image.network(user.certificateUrl,
                              height: 150,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Text(
                                      'Failed to load Certificate image')),
                        )
                      : const Column(children: [
                          Icon(Icons.image_not_supported,
                              color: Colors.grey, size: 50),
                          Text('No Certificate image available',
                              style: TextStyle(color: Colors.grey))
                        ]),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showImageOverlay(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black.withOpacity(0.8),
          insetPadding: const EdgeInsets.all(16),
          child: RawScrollbar(
            thumbColor: Colors.white, // White scrollbar
            radius: const Radius.circular(8), // Rounded scrollbar edges
            thickness: 6, // Thickness of the scrollbar
            isAlwaysShown: true, // Always show the scrollbar
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Column(
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: InteractiveViewer(
                                minScale: 1.0,
                                maxScale: 4.0,
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Text(
                                    'Failed to load image',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
