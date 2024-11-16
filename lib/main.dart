import 'dart:async';
import 'package:capstone/login/login.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Firebase initialization with platform-specific options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MyApp());
  } catch (e) {
    // Log or handle the error as needed (can also use Firebase Crashlytics)
    print('Firebase initialization failed: $e');
    runApp(const MyErrorApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Handimerce',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 1.0; // Initial opacity of the image

  @override
  void initState() {
    super.initState();

    // Start the fade-out effect after 2 seconds
    Timer(const Duration(seconds: 2), () {
      setState(() {
        _opacity = 0.0; // Set opacity to 0 to fade out
      });
    });

    // Navigate to LoginScreen after the fade-out animation
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(seconds: 1), // Duration of the fade-out effect
        child: Center(
          child: Image.asset(
            'img/screen.png',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

// Error screen in case Firebase initialization fails
class MyErrorApp extends StatelessWidget {
  const MyErrorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Initialization Error',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            'Failed to initialize Firebase. Please try again later.',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      ),
    );
  }
}
