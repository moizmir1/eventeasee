import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'firebase_options.dart';
import 'views/auth/login_screen.dart'; 
import 'views/customer/customer_home.dart'; 
import 'views/provider/provider_home.dart'; 
import 'views/provider/provider_setup_profile_screen.dart';
import 'views/admin/admin_home.dart'; 
import 'services/notification_service.dart'; 

void main() async {
  // Flutter binding ensure karna zaruri hai
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Firebase Init
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Notifications Init
    await NotificationService.initNotificationChannel();
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }

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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1)),
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
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!authSnapshot.hasData) return const LoginScreen();

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(authSnapshot.data!.uid)
              .snapshots(),
          builder: (context, firestoreSnapshot) {
            
            // Loading state for Firestore
            if (firestoreSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            // Error ya Data na hone ki surat mein Login per bhej dein
            if (firestoreSnapshot.hasError || !firestoreSnapshot.hasData || !firestoreSnapshot.data!.exists) {
              return const LoginScreen();
            }

            var userData = firestoreSnapshot.data!.data() as Map<String, dynamic>;
            
            // Security Check
            if (userData['isBlocked'] == true) {
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }

            String role = (userData['role'] ?? 'customer').toString().toLowerCase();

            if (role == 'admin') return const AdminHome();
            if (role == 'provider') {
              return (userData['isProfileComplete'] == true) 
                  ? const ProviderHome() 
                  : const ProviderSetupProfileScreen();
            }
            
            return const CustomerHome();
          },
        );
      },
    );
  }
}