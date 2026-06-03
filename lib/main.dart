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
import 'services/notification_service.dart'; // --- IMPORT: LOCAL NOTIFICATION ENGINE ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Core Firebase Initialization Pipeline
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. --- INITIALIZE: REAL-TIME NOTIFICATIONS CHANNELS ---
  await NotificationService.initNotificationChannel();

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), 
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFF10B981), 
          surface: const Color(0xFFF8FAFC), 
          error: const Color(0xFFEF4444), 
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          iconTheme: IconThemeData(color: Color(0xFF1E293B)),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1), 
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.2),
          ),
        ),
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authSnapshot.hasData && authSnapshot.data != null) {
          // --- REAL-TIME SECURITY SNAPSHOTSTREAM TO MONITOR BLOCK STATUS ---
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(authSnapshot.data!.uid)
                .snapshots(), // Changed to continuous snapshot stream for active checking
            builder: (context, firestoreSnapshot) {
              if (firestoreSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (firestoreSnapshot.hasData && firestoreSnapshot.data!.exists) {
                var userData = firestoreSnapshot.data!.data() as Map<String, dynamic>;
                
                // --- SECURITY GUARD INTERCEPTOR: FAKE ACCOUNTS BAN ---
                bool isBlocked = userData['isBlocked'] ?? false;
                if (isBlocked) {
                  // If admin blocks the account, log out immediately and throw user back
                  FirebaseAuth.instance.signOut();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("This account has been suspended by the administrator panel."),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  });
                  return const LoginScreen();
                }

                String role = (userData['role'] ?? 'customer').toString().toLowerCase();

                // --- ROLE 1: ADMIN SEPARATION SYSTEM ---
                if (role == 'admin') {
                  return const AdminHome(); 
                }

                // --- ROLE 2: SERVICE PROVIDER WITH ONBOARDING CHECK ---
                if (role == 'provider') {
                  bool isProfileComplete = userData['isProfileComplete'] ?? false;
                  
                  if (!isProfileComplete) {
                    return const ProviderSetupProfileScreen(); 
                  } else {
                    return const ProviderHome(); 
                  }
                }
              }

              // --- ROLE 3: DEFAULT FALLBACK (CUSTOMER PORTAL) ---
              return const CustomerHome();
            },
          );
        }

        return const LoginScreen(); 
      },
    );
  }
}