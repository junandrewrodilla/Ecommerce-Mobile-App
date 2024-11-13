import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:file_picker/file_picker.dart';

import 'buyer_page.dart';
import 'seller_page.dart';
import 'admin_page.dart';

class EditProfileScreen extends StatefulWidget {
  final String uid; // User ID to save profile data

  const EditProfileScreen({Key? key, required this.uid}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseStorage _storage =
      FirebaseStorage.instance; // Firebase storage reference

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _birthdateController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _barangayController = TextEditingController();
  final TextEditingController _otherDetailsController = TextEditingController();

  String? userType;
  DateTime? _selectedBirthdate;
  int _currentStep = 0;
  String? _errorMessage;
  File? _validIdFile;
  File? _certificateFile;

  // Initialize the user type in an async function, called in initState
  @override
  void initState() {
    super.initState();
    _fetchUserType();
  }

  Future<void> _fetchUserType() async {
    try {
      DataSnapshot snapshot = await _database
          .child('users')
          .child(widget.uid)
          .child('userprofiles')
          .get();
      if (snapshot.exists) {
        setState(() {
          userType = snapshot.child('user_type').value as String?;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch user type. Please try again.';
      });
    }
  }

  Future<void> _saveProfile() async {
    // Check if a valid ID file is selected
    if (_validIdFile == null) {
      setState(() {
        _errorMessage = 'Please upload a valid ID to save your profile.';
      });
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      // Upload the valid ID file
      String? validIdUrl =
          await _uploadFileToStorage(_validIdFile!, 'valid_id');

      // Upload the certificate file only if it’s available
      String? certificateUrl = _certificateFile != null
          ? await _uploadFileToStorage(_certificateFile!, 'certificate')
          : null;

      // Save data in the Firebase Realtime Database
      await _database
          .child('users')
          .child(widget.uid)
          .child('userprofiles')
          .update({
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'middle_name': _middleNameController.text,
        'birthdate': _birthdateController.text,
        'address': _addressController.text,
        'province': _provinceController.text,
        'city': _cityController.text,
        'barangay': _barangayController.text,
        'other_details': _otherDetailsController.text,
        'valid_id_url': validIdUrl, // Store the file URL
        'certificate_url': certificateUrl, // Store the file URL if available
        'profile_setup_complete': true,
      });

      // Check the user type and navigate to the corresponding home page
      DataSnapshot snapshot = await _database
          .child('users')
          .child(widget.uid)
          .child('userprofiles')
          .get();
      Navigator.pop(context);

      if (snapshot.exists) {
        String? userType = snapshot.child('user_type').value as String?;

        if (userType == 'Seller') {
          // ignore: use_build_context_synchronously
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => SellerHomePage()));
        } else if (userType == 'Buyer') {
          // ignore: use_build_context_synchronously
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => BuyerHomePage()));
        } else if (userType == 'Admin') {
          // ignore: use_build_context_synchronously
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => AdminHomePage()));
        } else {
          setState(() {
            _errorMessage = "Unknown user type. Please contact support.";
          });
        }
      }
    } catch (e) {
      Navigator.pop(context);
      setState(() {
        _errorMessage = "Failed to save profile. Please try again.";
      });
    }
  }

  Future<String?> _uploadFileToStorage(File file, String folderName) async {
    try {
      final String fileName = file.path.split('/').last;
      final Reference storageRef =
          _storage.ref().child('$folderName/${widget.uid}/$fileName');
      final UploadTask uploadTask = storageRef.putFile(file);
      final TaskSnapshot downloadUrl = await uploadTask;
      final String url = await downloadUrl.ref.getDownloadURL();
      return url;
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to upload $folderName. Please try again.';
      });
      return null;
    }
  }

  Future<void> _selectBirthdate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthdate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthdate) {
      setState(() {
        _selectedBirthdate = picked;
        _birthdateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return setState(() {
        _errorMessage = 'Location services are disabled.';
      });
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return setState(() {
          _errorMessage = 'Location permissions are denied.';
        });
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return setState(() {
        _errorMessage = 'Location permissions are permanently denied.';
      });
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _reverseGeocodePosition(position);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get location. Please try again.';
      });
    }
  }

  Future<void> _reverseGeocodePosition(Position position) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          _provinceController.text = place.administrativeArea ?? '';
          _cityController.text = place.locality ?? '';
          _barangayController.text = place.subLocality ?? '';
          _addressController.text =
              '${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}';
          _otherDetailsController.text =
              'Lat: ${position.latitude}, Lng: ${position.longitude}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get address. Please try again.';
      });
    }
  }

  Future<void> _pickFile(String documentType) async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg']);

    if (result != null && result.files.single.path != null) {
      setState(() {
        if (documentType == 'Valid ID') {
          _validIdFile = File(result.files.single.path!);
        } else if (documentType == 'Certificate') {
          _certificateFile = File(result.files.single.path!);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    final double buttonHeight = isMobile ? 50.0 : 60.0;
    final double buttonFontSize = isMobile ? 16.0 : 18.0;

    return WillPopScope(
      onWillPop: () async {
        // Prevent back navigation
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Register'),
          backgroundColor: const Color(0xFFA00000),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 32),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Center(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                _buildStepIndicator(),
                const SizedBox(height: 16),
                if (_currentStep == 0)
                  _buildStep1(buttonHeight, buttonFontSize),
                if (_currentStep == 1)
                  _buildStep2(buttonHeight, buttonFontSize),
                if (_currentStep == 2)
                  _buildStep3(buttonHeight, buttonFontSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Other step widgets, field validation methods, and location methods remain unchanged.

  Widget _buildStep1(double buttonHeight, double buttonFontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Name',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildTextField(
            controller: _firstNameController, labelText: 'First Name'),
        const SizedBox(height: 16),
        _buildTextField(
            controller: _middleNameController, labelText: 'Middle Name'),
        const SizedBox(height: 16),
        _buildTextField(
            controller: _lastNameController, labelText: 'Last Name'),
        const SizedBox(height: 16),
        TextField(
          controller: _birthdateController,
          decoration: InputDecoration(
            labelText: 'Birthdate',
            suffixIcon: const Icon(Icons.calendar_today),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          readOnly: true,
          onTap: () => _selectBirthdate(context),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (_validateStep1()) {
                setState(() {
                  _currentStep = 1;
                  _errorMessage = null;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, buttonHeight),
              textStyle: TextStyle(fontSize: buttonFontSize),
              backgroundColor: const Color(0xFFA00000),
            ),
            child: const Text('Next'),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(double buttonHeight, double buttonFontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Address',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildTextField(controller: _addressController, labelText: 'Address'),
        const SizedBox(height: 16),
        _buildTextField(controller: _provinceController, labelText: 'Province'),
        const SizedBox(height: 16),
        _buildTextField(controller: _cityController, labelText: 'City'),
        const SizedBox(height: 16),
        _buildTextField(controller: _barangayController, labelText: 'Barangay'),
        const SizedBox(height: 16),
        _buildTextField(
            controller: _otherDetailsController,
            labelText: 'Other (Street, Prk, Blk)'),
        const SizedBox(height: 16),
        _buildLocationButton(buttonHeight, buttonFontSize),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 0;
                    _errorMessage = null;
                  });
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, buttonHeight),
                  textStyle: TextStyle(fontSize: buttonFontSize),
                  backgroundColor: const Color(0xFFA00000),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (_validateStep2()) {
                    setState(() {
                      _currentStep = 2;
                      _errorMessage = null;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, buttonHeight),
                  textStyle: TextStyle(fontSize: buttonFontSize),
                  backgroundColor: const Color(0xFFA00000),
                ),
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3(double buttonHeight, double buttonFontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Upload Documents',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _pickFile('Valid ID'),
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload Valid ID'),
          style: ElevatedButton.styleFrom(
            primary: const Color(0xFFA00000),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            textStyle: TextStyle(fontSize: buttonFontSize),
          ),
        ),
        const SizedBox(height: 8),
        _validIdFile != null
            ? Text('Selected file: ${_validIdFile!.path.split('/').last}')
            : const Text('No valid ID selected.'),

        // Conditionally display certificate upload for non-buyer types
        if (userType != 'Buyer') ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _pickFile('Certificate'),
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Certificate of Ancestral Domain'),
            style: ElevatedButton.styleFrom(
              primary: const Color(0xFFA00000),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              textStyle: TextStyle(fontSize: buttonFontSize),
            ),
          ),
          const SizedBox(height: 8),
          _certificateFile != null
              ? Text('Selected file: ${_certificateFile!.path.split('/').last}')
              : const Text('No certificate selected.'),
        ],

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 1;
                    _errorMessage = null;
                  });
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, buttonHeight),
                  textStyle: TextStyle(fontSize: buttonFontSize),
                  backgroundColor: const Color(0xFFA00000),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, buttonHeight),
                  textStyle: TextStyle(fontSize: buttonFontSize),
                  backgroundColor: const Color(0xFFA00000),
                ),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _validateStep1() {
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _birthdateController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all required fields.';
      });
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (_addressController.text.isEmpty ||
        _provinceController.text.isEmpty ||
        _cityController.text.isEmpty ||
        _barangayController.text.isEmpty ||
        _otherDetailsController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all required fields.';
      });
      return false;
    }
    return true;
  }

  void _changeStep(int step) {
    if (step == 0) {
      setState(() {
        _currentStep = 0;
        _errorMessage = null;
      });
    } else if (step == 1 && _validateStep1()) {
      setState(() {
        _currentStep = 1;
        _errorMessage = null;
      });
    } else if (step == 2 && _validateStep2()) {
      setState(() {
        _currentStep = 2;
        _errorMessage = null;
      });
    }
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepButton('Step 1', 0),
        const SizedBox(width: 8),
        _buildStepButton('Step 2', 1),
        const SizedBox(width: 8),
        _buildStepButton('Step 3', 2),
      ],
    );
  }

  Widget _buildStepButton(String label, int step) {
    return ElevatedButton(
      onPressed: () {
        _changeStep(step);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            _currentStep == step ? const Color(0xFFA00000) : Colors.grey[300],
        textStyle: TextStyle(
          color: _currentStep == step ? Colors.white : Colors.black,
        ),
      ),
      child: Text(label),
    );
  }

  Widget _buildLocationButton(double buttonHeight, double buttonFontSize) {
    return ElevatedButton.icon(
      onPressed: _getLocation,
      icon: const Icon(Icons.location_on),
      label: const Text('Use Current Location'),
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, buttonHeight),
        textStyle: TextStyle(fontSize: buttonFontSize),
        backgroundColor: const Color(0xFFA00000),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Color.fromARGB(255, 82, 0, 0)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color.fromARGB(255, 189, 0, 0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
      ),
      cursorColor: const Color(0xFFA00000),
      keyboardType: keyboardType,
    );
  }
}
