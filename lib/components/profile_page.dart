import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:capstone/login/login.dart';

class ProfilePage extends StatefulWidget {
  final String userId;

  const ProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  Map<String, dynamic>? _userProfile;
  File? _image;
  final ImagePicker _picker = ImagePicker();
  String? _profileImageUrl;
  bool _isLoading = true;
  bool _isDeactivated = false;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      DatabaseEvent event =
          await _database.child('users/${widget.userId}/userprofiles').once();

      if (event.snapshot.exists) {
        setState(() {
          _userProfile = Map<String, dynamic>.from(
              event.snapshot.value as Map<Object?, Object?>);
          _profileImageUrl = _userProfile?['profile_image'] ?? '';
          _isDeactivated = _userProfile?['Deactivate'] == true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _userProfile = null;
        });
        debugPrint('User profile not found.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint("Error fetching user profile: $e");
    }
  }

  Future<void> _selectImage() async {
    final XFile? pickedImage =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _image = File(pickedImage.path);
      });
      await _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    try {
      if (_image == null) return;
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${widget.userId}.jpg');
      await ref.putFile(_image!);
      final imageUrl = await ref.getDownloadURL();
      await _database
          .child('users/${widget.userId}/userprofiles')
          .update({'profile_image': imageUrl});

      setState(() {
        _profileImageUrl = imageUrl;
      });
    } catch (e) {
      debugPrint('Error uploading image: $e');
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut(); // Sign out from Google as well
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      debugPrint("Error logging out: $e");
    }
  }

  Future<void> _deactivateAccount() async {
    try {
      // Update the database to deactivate the account
      await _database
          .child('users/${widget.userId}/userprofiles')
          .update({'Deactivate': true});
      debugPrint('Account deactivated.');

      // Log the user out after deactivation
      await _logout(context);
    } catch (e) {
      debugPrint('Error deactivating account: $e');
    }
  }

  Future<void> _activateAccount() async {
    try {
      await _database
          .child('users/${widget.userId}/userprofiles')
          .update({'Deactivate': false});
      setState(() {
        _isDeactivated = false;
      });
      debugPrint('Account activated.');
    } catch (e) {
      debugPrint('Error activating account: $e');
    }
  }

  void _confirmDeactivation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deactivation'),
          content:
              const Text('Are you sure you want to deactivate your account?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deactivateAccount();
              },
              child: const Text('Deactivate'),
            ),
          ],
        );
      },
    );
  }

  void _editProfile() {
    final TextEditingController firstNameController =
        TextEditingController(text: _userProfile?['first_name']);
    final TextEditingController middleNameController =
        TextEditingController(text: _userProfile?['middle_name']);
    final TextEditingController lastNameController =
        TextEditingController(text: _userProfile?['last_name']);
    final TextEditingController contactNumberController =
        TextEditingController(text: _userProfile?['contact_number']);
    final TextEditingController addressController =
        TextEditingController(text: _userProfile?['address']);
    final TextEditingController cityController =
        TextEditingController(text: _userProfile?['city']);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name'),
                ),
                TextField(
                  controller: middleNameController,
                  decoration: const InputDecoration(labelText: 'Middle Name'),
                ),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                ),
                TextField(
                  controller: contactNumberController,
                  decoration:
                      const InputDecoration(labelText: 'Contact Number'),
                ),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _database
                    .child('users/${widget.userId}/userprofiles')
                    .update({
                  'first_name': firstNameController.text,
                  'middle_name': middleNameController.text,
                  'last_name': lastNameController.text,
                  'contact_number': contactNumberController.text,
                  'address': addressController.text,
                  'city': cityController.text,
                });
                Navigator.pop(context);
                _fetchUserProfile();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 600;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userProfile == null) {
      return const Center(
        child: Text(
          'Profile not found.',
          style: TextStyle(fontSize: 18, color: Colors.red),
        ),
      );
    }

    String firstName = _userProfile?['first_name'] ?? 'First Name';
    String middleName = _userProfile?['middle_name'] ?? 'Middle Name';
    String lastName = _userProfile?['last_name'] ?? 'Last Name';
    String email = _userProfile?['email'] ?? 'Email';
    String address = _userProfile?['address'] ?? 'Address';
    String contactNumber = _userProfile?['contact_number'] ?? 'Contact Number';
    String city = _userProfile?['city'] ?? 'City';
    String userType = _userProfile?['user_type'] ?? 'User Type';

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      contentPadding: const EdgeInsets.all(16.0),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                color: Colors.red[900],
                iconSize: 20,
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: _profileImageUrl != null &&
                          _profileImageUrl!.isNotEmpty
                      ? NetworkImage(_profileImageUrl!)
                      : const AssetImage('assets/profile.jpg') as ImageProvider,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _selectImage,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '$firstName $middleName $lastName',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              userType,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              city,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              email,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              contactNumber,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              address,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _editProfile,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: Colors.blue,
              ),
              child: const Text(
                'Edit Profile',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (userType != 'Admin')
              _isDeactivated
                  ? ElevatedButton(
                      onPressed: _activateAccount,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: Colors.green,
                      ),
                      child: const Text(
                        'Activate Account',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _confirmDeactivation,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: Colors.orange,
                      ),
                      child: const Text(
                        'Deactivate Account',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
            const SizedBox(height: 10),
            if (!isWeb) // Show logout button only if not on web
              ElevatedButton(
                onPressed: () => _logout(context),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: Colors.red[900],
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
