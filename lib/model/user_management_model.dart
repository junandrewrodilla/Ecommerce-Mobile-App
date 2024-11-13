class User {
  final String uid;
  final String firstName;
  final String lastName;
  final String middleName;
  final String userType;
  final String address;
  final String email;
  final bool sellerApproval;
  final String validIdUrl; // Add validId URL field
  final String certificateOfAncestralDomainUrl; // Add certificate URL field

  User({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.middleName,
    required this.userType,
    required this.address,
    required this.email,
    required this.sellerApproval,
    required this.validIdUrl, // Initialize validIdUrl
    required this.certificateOfAncestralDomainUrl, // Initialize certificate URL
  });

  // Factory method to create a User from Firebase snapshot
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
      validIdUrl: data['valid_id'] ?? '', // Map the valid ID URL
      certificateOfAncestralDomainUrl:
          data['certificate_of_ancestral_domain'] ?? '', // Map certificate URL
    );
  }
}
