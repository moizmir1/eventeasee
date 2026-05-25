import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import your new dashboard files
import '../customer/customer_home.dart';
import '../provider/provider_home.dart';
import '../admin/admin_home.dart';
import 'signup_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // This "listens" to see if a user is logged in or out
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        
        // 1. If NO user is logged in, show the Signup Screen
        if (!snapshot.hasData) {
          return const SignupScreen();
        }

        // 2. If a user IS logged in, check their role in the database
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .get(),
          builder: (context, roleSnapshot) {
            // While the app is "thinking" and fetching the role, show a loading spinner
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Get the role string from the database (default to 'customer' if missing)
            String role = roleSnapshot.data?['role'] ?? 'customer';

            // 3. Send the user to the correct Dashboard
            if (role == 'admin') {
              return const AdminHome();
            } else if (role == 'provider') {
              return const ProviderHome();
            } else {
              return const CustomerHome();
            }
          },
        );
      },
    );
  }
}