import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Sign Up Function
  Future<User?> signUp(String email, String password, String role) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      User? user = result.user;

      // Save the user role to Firestore database
      if (user != null) {
        await _db.collection('users').doc(user.uid).set({
          'email': email,
          'role': role,
          'createdAt': DateTime.now(),
          'isBlocked': false, // 🚀 ADDED INITIAL ACCOUNT CONTROL STATE PARAMETER
        });
      }
      return user;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // 🚀 AUTOMATED DEEP AUDIT LOGIN ENGINE (STOPS BANNED USERS ON THE SPOT)
  Future<User?> login(String email, String password) async {
    try {
      // 1. Authenticate user credentials via Firebase Auth module
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      
      User? user = result.user;

      if (user != null) {
        // 2. Fetch corresponding documentation row from firestore index instantly
        DocumentSnapshot userDoc = await _db.collection('users').doc(user.uid).get();

        if (userDoc.exists && userDoc.data() != null) {
          var userData = userDoc.data() as Map<String, dynamic>;
          
          // 3. Check if account is suspended for communication or spam abuses
          if (userData['isBlocked'] == true) {
            // Force terminate active network token session boundaries safely
            await _auth.signOut();
            
            // Throw custom security message parsed straight into UI views try-catches
            throw FirebaseAuthException(
              code: 'user-disabled',
              message: "Your account has been permanently suspended for breaching platform rules.",
            );
          }
        }
      }
      
      return user;
    } catch (e) {
      print("Authentication Pipeline Exception: ${e.toString()}");
      // Rethrow to handle specific block alerts smoothly inside UI Snackbars too
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}