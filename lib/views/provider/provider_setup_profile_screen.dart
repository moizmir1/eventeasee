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
  
  // --- MULTI-SELECT LIST ---
  final List<String> _selectedCategories = [];
  bool _isLoading = false;

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one service category")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Saving provider professional details with categories Array
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'categories': _selectedCategories, // Saved as an Array/List in Firestore
        'role': 'provider',          
        'rating': 5.0,               
        'isProfileComplete': true,   
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
                      "Complete your business profile. You can select multiple services that your business offers.",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 25),
                    
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Business / Professional Name",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business_center),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? "Name is required" : null,
                    ),
                    const SizedBox(height: 25),
                    
                    // --- MULTI-SELECT CHIPS VIEW ---
                    const Text(
                      "Select Your Services (Multiple Allowed):",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _categories.map((category) {
                        final isSelected = _selectedCategories.contains(category);
                        return FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          selectedColor: const Color(0xFF6366F1).withOpacity(0.2),
                          checkmarkColor: const Color(0xFF6366F1),
                          labelStyle: TextStyle(
                            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF475569),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0)),
                          ),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                _selectedCategories.add(category);
                              } else {
                                _selectedCategories.remove(category);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 25),
                    
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
                    
                    ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(55),
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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