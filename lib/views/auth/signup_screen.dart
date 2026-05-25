import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'customer'; // Default role
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Event Easee Account")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            const Text("Register as a:"),
            DropdownButton<String>(
              value: _selectedRole,
              items: const [
                DropdownMenuItem(value: 'customer', child: Text("Customer")),
                DropdownMenuItem(value: 'provider', child: Text("Service Provider")),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedRole = val!;
                });
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                var user = await _auth.signUp(
                  _emailController.text,
                  _passwordController.text,
                  _selectedRole,
                );
                if (user != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Account Created Successfully!")),
                  );
                }
              },
              child: const Text("Sign Up"),
            ),
            TextButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  },
  child: const Text("Already have an account? Login here"),
),
          ],
        ),
      ),
    );
  }
}