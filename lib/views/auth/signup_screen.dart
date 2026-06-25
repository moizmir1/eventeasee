import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(); // 🚀 NAME CONTROLLER
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String _selectedRole = 'customer'; 
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  void _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create User
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Initialize Firestore Record
      if (userCredential.user != null) {
        Map<String, dynamic> userPayload = {
          'uid': userCredential.user!.uid,
          'name': _nameController.text.trim(), // 🚀 SAVING NAME
          'email': _emailController.text.trim(),
          'role': _selectedRole,
          'isBlocked': false, // 🚀 ADMIN PANEL NEED THIS
          'createdAt': FieldValue.serverTimestamp(),
        };

        if (_selectedRole == 'provider') {
          userPayload['isProfileComplete'] = false;
          userPayload['categories'] = [];
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(userPayload);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Color(0xFF10B981), content: Text("Account created successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Signup Error: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text("Create Account"), backgroundColor: Colors.white, elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Join Event Easee", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    const SizedBox(height: 25),
                    
                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                      validator: (value) => value == null || value.trim().isEmpty ? "Name is required" : null,
                    ),
                    const SizedBox(height: 20),

                    // Role Selector
                    Row(
                      children: [
                        _buildRoleSelector('customer', 'Customer', Icons.person_outline),
                        const SizedBox(width: 16),
                        _buildRoleSelector('provider', 'Vendor / Provider', Icons.business_center_outlined),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: "Email Address", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined)),
                      validator: (value) => value == null || value.trim().isEmpty ? "Email is required" : null,
                    ),
                    const SizedBox(height: 20),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: "Password", border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)),
                      ),
                      validator: (value) => value == null || value.length < 6 ? "Minimum 6 characters" : null,
                    ),
                    const SizedBox(height: 20),

                    // Confirm Password
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: "Confirm Password", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_reset_outlined)),
                      validator: (value) => value != _passwordController.text ? "Passwords do not match" : null,
                    ),
                    const SizedBox(height: 30),

                    ElevatedButton(
                      onPressed: _handleSignup,
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(55), backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: const Text("Register Account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRoleSelector(String role, String label, IconData icon) {
    bool isSelected = _selectedRole == role;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedRole = role),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: isSelected ? const Color(0xFF6366F1).withOpacity(0.1) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0), width: 2)),
          child: Column(children: [Icon(icon, color: isSelected ? const Color(0xFF6366F1) : Colors.grey), const SizedBox(height: 6), Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF6366F1) : Colors.grey))]),
        ),
      ),
    );
  }
}