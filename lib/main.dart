import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'firebase_options.dart';
import 'views/auth/login_screen.dart'; 
import 'views/customer/customer_home.dart'; 
import 'views/provider/provider_home.dart'; 
import 'views/provider/provider_setup_profile_screen.dart'; // Naya profile setup screen import kiya

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Event Easee',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // 1. Check if Firebase Auth is waiting
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. If user is logged in, check their role and profile status in Firestore
        if (authSnapshot.hasData && authSnapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(authSnapshot.data!.uid)
                .get(),
            builder: (context, firestoreSnapshot) {
              // Loading check while fetching user data
              if (firestoreSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              // Check if document exists and read fields
              if (firestoreSnapshot.hasData && firestoreSnapshot.data!.exists) {
                var userData = firestoreSnapshot.data!.data() as Map<String, dynamic>;
                String role = userData['role'] ?? 'customer'; // Default fallback

                if (role.toLowerCase() == 'provider') {
                  // --- SMART CHECK FOR INCOMPLETE PROFILE ---
                  bool isProfileComplete = userData['isProfileComplete'] ?? false;
                  
                  if (!isProfileComplete) {
                    return const ProviderSetupProfileScreen(); // Setup page if details are missing
                  } else {
                    return const ProviderHome(); // Regular Dashboard if all good
                  }
                }
              }

              // Default if role is customer or not found
              return const CustomerHome();
            },
          );
        }

        // 3. If not logged in, show Login Screen
        return const LoginScreen(); 
      },
    );
  }
}