import 'package:capstone/home/edit_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class RegisterGoogleScreen extends StatelessWidget {
  final String uid;

  const RegisterGoogleScreen({Key? key, required this.uid}) : super(key: key);

  Future<String?> _signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // User canceled sign-in

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    UserCredential userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);

    return userCredential.user?.email; // Retrieve the user's email
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController contactNumberController =
        TextEditingController();
    String userType = 'Buyer'; // Default to 'Buyer'

    return Scaffold(
      backgroundColor: Colors.red, // Red background behind the container
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24.0),
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          decoration: BoxDecoration(
            color: Colors.white, // White background for the container
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contact Number Input
              TextField(
                controller: contactNumberController,
                decoration: const InputDecoration(
                  labelText: 'Contact Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // User Type Dropdown
              const Text('User Type:'),
              DropdownButtonFormField<String>(
                value: userType,
                items: const [
                  DropdownMenuItem(value: 'Buyer', child: Text('Buyer')),
                  DropdownMenuItem(value: 'Seller', child: Text('Seller')),
                ],
                onChanged: (String? newValue) {
                  if (newValue != null) userType = newValue;
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Sign Up Button aligned to bottom right
              Align(
                alignment: Alignment.bottomRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[900], // Dark red button color
                  ),
                  onPressed: () async {
                    final contactNumber = contactNumberController.text;
                    final email = await _signInWithGoogle();

                    if (email != null) {
                      // Save contact number, user type, and email to Firebase
                      await FirebaseDatabase.instance
                          .ref('users/$uid/userprofiles')
                          .set({
                        'contact_number': contactNumber,
                        'user_type': userType,
                        'email': email,
                        'profile_setup_complete': false,
                      });

                      // Navigate to EditProfileScreen after saving
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(uid: uid),
                        ),
                      );
                    }
                  },
                  child: const Text('Sign Up'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
