import 'package:capstone/home/admin_page.dart';
import 'package:capstone/home/buyer_page.dart';
import 'package:capstone/home/edit_profile.dart';
import 'package:capstone/home/seller_page.dart';
import 'package:capstone/login/Register_google.dart';
import 'package:capstone/login/register.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _errorMessage;
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkLoginState(); // Check user session on widget initialization
  }

  Future<void> _checkLoginState() async {
    User? user = _auth.currentUser;

    if (user != null) {
      setState(() {
        _isLoading = true; // Show loading spinner while fetching user data
      });

      DataSnapshot snapshot = await _database
          .child('users')
          .child(user.uid)
          .child('userprofiles')
          .get();

      if (snapshot.exists) {
        bool isDeactivated = snapshot.child('Deactivate').value == true;

        if (isDeactivated) {
          setState(() {
            _errorMessage = "This account is deactivated.";
            _isLoading = false; // Hide loading spinner
          });
          await _auth.signOut(); // Sign out to prevent access
          return;
        }

        bool profileSetupComplete =
            snapshot.child('profile_setup_complete').value == true;
        String? userType = snapshot.child('user_type').value as String?;

        if (profileSetupComplete && userType != null) {
          // Navigate to the appropriate home page based on user type
          if (userType == 'Seller') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => SellerHomePage()),
            );
          } else if (userType == 'Buyer') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => BuyerHomePage()),
            );
          } else if (userType == 'Admin') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => AdminHomePage()),
            );
          }
        } else {
          // Navigate to edit profile if setup is not complete
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => EditProfileScreen(uid: user.uid)),
          );
        }
      } else {
        setState(() {
          _errorMessage = "User data not found!";
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false; // Hide loading spinner when no user is found
      });
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true; // Show loading spinner during login process
      _errorMessage = null;
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      final DataSnapshot snapshot = await _database
          .child('users')
          .child(userCredential.user!.uid)
          .child('userprofiles')
          .get();

      if (snapshot.exists) {
        bool isDeactivated = snapshot.child('Deactivate').value == true;
        if (isDeactivated) {
          setState(() {
            _errorMessage = "This account is deactivated.";
            _isLoading = false;
          });
          await _auth.signOut(); // Immediately sign out
          return;
        }
      }

      await _checkLoginState(); // Check login state and redirect accordingly
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false; // Hide spinner if an error occurs
        switch (e.code) {
          case 'invalid-email':
            _errorMessage = "The email address is badly formatted.";
            break;
          case 'user-not-found':
            _errorMessage = "No user found with this email.";
            break;
          case 'wrong-password':
            _errorMessage = "The password is incorrect.";
            break;
          case 'too-many-requests':
            _errorMessage = "Too many login attempts. Try again later.";
            break;
          default:
            _errorMessage = "Login failed. Please try again.";
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = "An error occurred. Please try again.";
        _isLoading = false;
      });
    }
  }

  Future<void> _forgotPassword() async {
    final emailController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Password"),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(hintText: "Enter your email"),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text("Send"),
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isNotEmpty) {
                try {
                  await _auth.sendPasswordResetEmail(email: email);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Password reset email sent!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                } on FirebaseAuthException catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          e.message ?? "Failed to send password reset email."),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // Web platform, use signInWithPopup
        userCredential = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        // Non-web platforms (iOS/Android)
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          setState(() {
            _isLoading = false;
            _errorMessage = "Google sign-in canceled.";
          });
          return;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      final User? user = userCredential.user;

      if (user != null) {
        final uid = user.uid;

        // Check if the user profile setup is complete
        final DataSnapshot snapshot = await _database
            .child('users')
            .child(uid)
            .child('userprofiles')
            .get();

        bool isDeactivated = snapshot.child('Deactivate').value == true;

        if (isDeactivated) {
          setState(() {
            _errorMessage = "This account is deactivated.";
            _isLoading = false;
          });
          await _auth.signOut();
          return;
        }

        bool profileSetupComplete =
            snapshot.child('profile_setup_complete').value == true;

        if (profileSetupComplete) {
          await _checkLoginState();
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RegisterGoogleScreen(uid: uid),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Google sign-in failed. Please try again.";
      });
    }
  }

  void _navigateToRegister() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RegisterScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0); // From right to left
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      ),
    );
  }

  Future<bool> _onWillPop() async {
    // Returning false to prevent the back button from doing anything
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.red,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildLoginForm(),
      ),
    );
  }

  Widget _buildLoginForm() {
    final screenWidth = MediaQuery.of(context).size.width;
    double containerWidth = screenWidth < 600 ? screenWidth * 0.9 : 400;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            width: containerWidth,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 5,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 16),
                Image.asset(
                  'img/logo123.jpg',
                  width: 500,
                  height: 140,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Log in with your data that you entered during your registration.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email address',
                    labelStyle: TextStyle(color: Colors.red[900]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red[900]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red[900]!),
                    ),
                    prefixIcon: const Icon(Icons.email, color: Colors.red),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red[900]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red[900]!),
                    ),
                    hintStyle: TextStyle(color: Colors.red[900]),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: Colors.red[900]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red[900]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red[900]!),
                    ),
                    prefixIcon: const Icon(Icons.lock, color: Colors.red),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red[900]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red[900]!),
                    ),
                    hintStyle: TextStyle(color: Colors.red[900]),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _forgotPassword,
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: Color(0xFF8B0000),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                _isLoading
                    ? const CircularProgressIndicator()
                    : Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          color: Colors.red, // Red button
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          onPressed: _login,
                          child: const Text(
                            'Log in',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 20),

                // Google Sign-In Button with Google logo and light red border
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.redAccent,
                      width: 2,
                    ),
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    icon: Image.asset(
                      'img/google logo.png',
                      height: 24,
                      width: 24,
                    ),
                    onPressed: _signInWithGoogle,
                    label: const Text(
                      'Sign in with Google',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Text("Don't have an account?"),
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: _navigateToRegister,
                      child: const Text(
                        'Sign up',
                        style: TextStyle(
                          color: Color(0xFF8B0000),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
