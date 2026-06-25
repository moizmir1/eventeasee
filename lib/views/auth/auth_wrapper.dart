import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../customer/customer_home.dart';
import '../provider/provider_home.dart';
import '../admin/admin_home.dart';
import 'login_screen.dart'; // Yahan Signup ki jagah Login use karein

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. User logged in nahi hai
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (!snapshot.hasData) {
          return const LoginScreen(); 
        }

        // 2. User logged in hai, Firestore check karein
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .get(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            // ⚠️ CRITICAL FIX: Agar document exist nahi karta, toh user ko logout kar dein
            if (!roleSnapshot.hasData || !roleSnapshot.data!.exists) {
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }

            // Role fetch karein
            String role = (roleSnapshot.data!.get('role') ?? 'customer').toString().toLowerCase();

            // 3. Navigation Logic
            if (role == 'admin') return const AdminHome();
            if (role == 'provider') return const ProviderHome();
            return const CustomerHome();
          },
        );
      },
    );
  }
}