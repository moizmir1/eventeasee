class AppUser {
  final String uid;
  final String email;
  final String role; // 'customer', 'provider', or 'admin'

  AppUser({required this.uid, required this.email, required this.role});

  // Converts Database data into this Flutter Object
  factory AppUser.fromMap(Map<String, dynamic> data, String id) {
    return AppUser(
      uid: id,
      email: data['email'] ?? '',
      role: data['role'] ?? 'customer',
    );
  }

  // Converts this Object back into Database data
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
    };
  }
}