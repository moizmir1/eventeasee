import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'provider_home.dart';

class ProviderSetupProfileScreen extends StatefulWidget {
  const ProviderSetupProfileScreen({super.key});

  @override
  State<ProviderSetupProfileScreen> createState() => _ProviderSetupProfileScreenState();
}

class _ProviderSetupProfileScreenState extends State<ProviderSetupProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  
  // Available services categories list
  final List<String> _categories = [
    'Photography',
    'Catering & Food',
    'Stage Decoration',
    'Sound System & DJ',
    'Event Planner',
    'Makeup Artist'
  ];
  
  String? _selectedCategory;
  bool _isLoading = false;

  void _saveProfile() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select your service category")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Saving provider professional details to Firestore 'users' collection
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'category': _selectedCategory,
        'role': 'provider',          // Enforcing role stability
        'rating': 5.0,               // Default starting rating for new professional
        'isProfileComplete': true,   // Flag to control main routing dashboard
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProviderHome()),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setup Business Profile"), automaticallyImplyLeading: false),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Complete your business profile to start receiving event leads and placing bids.",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 25),
                    
                    // Input 1: Business / Professional Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Business / Professional Name",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business_center),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? "Name is required" : null,
                    ),
                    const SizedBox(height: 20),
                    
                    // Input 2: Services / Category Dropdown Filter Selector
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: "Select Your Main Service",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.design_services),
                      ),
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedCategory = newValue;
                        });
                      },
                      validator: (value) => value == null ? "Please select a service category" : null,
                    ),
                    const SizedBox(height: 20),
                    
                    // Input 3: Professional Bio / Previous Work Experience Summary
                    TextFormField(
                      controller: _bioController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: "About Your Business / Experience",
                        hintText: "Describe your team, package deals, or equipment setup details...",
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? "Please write a short description" : null,
                    ),
                    const SizedBox(height: 30),
                    
                    // Action Submit Button
                    ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(55),
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Save & Open Dashboard", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}