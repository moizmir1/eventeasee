import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:flutter/foundation.dart' show Uint8List;
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _avatarUrlController = TextEditingController(); 
  
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<String> _selectedCategories = []; 
  final List<String> _availableCategories = [
    "Photography",
    "Catering",
    "Stage Design",
    "Sound System",
    "Event Coordination"
  ];

  bool _isLoading = false;
  bool _isEditing = false;
  String _userRole = 'customer'; 

  @override
  void initState() {
    super.initState();
    _fetchUserProfileData();
  }

  void _fetchUserProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        var data = userDoc.data() as Map<String, dynamic>;
        
        setState(() {
          _userRole = data['role'] ?? 'customer';
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _avatarUrlController.text = data['profilePic'] ?? '';
          
          if (_userRole == 'provider') {
            _businessNameController.text = data['businessName'] ?? '';
            _descriptionController.text = data['description'] ?? '';
            
            if (data['categories'] != null) {
              _selectedCategories = List<String>.from(data['categories']);
            } else if (data['category'] != null) {
              _selectedCategories = [data['category']];
            }
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching records: ${e.toString()}"), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 🚀 100% LOCAL BASE64 CONVERSION & ERROR-FREE STORAGE ENGINE
  void _uploadProfileImageFromDevice() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ImagePicker picker = ImagePicker();
    // imageQuality setting at 25 keeps database string perfectly lightweight and ultra-fast
    final XFile? selectedImage = await picker.pickImage(source: ImageSource.gallery, imageQuality: 25);

    if (selectedImage != null) {
      setState(() => _isLoading = true);
      try {
        // Read selected image bytes instantly from local machine buffer memory
        Uint8List synchronousDataBytes = await selectedImage.readAsBytes();
        
        // Convert the real photo into high-fidelity independent text format data string
        String base64ImageString = base64Encode(synchronousDataBytes);
        String completeBase64Payload = "data:image/jpeg;base64,$base64ImageString";

        // Save your actual photo directly into Firestore document, fully bypassing Storage buckets!
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'profilePic': completeBase64Payload,
        });

        setState(() {
          _avatarUrlController.text = completeBase64Payload;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile picture updated successfully!"), backgroundColor: Color(0xFF10B981)),
          );
        }
      } catch (ex) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Memory Sync Error: ${ex.toString()}"), backgroundColor: Colors.redAccent)
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _saveProfileChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_userRole == 'provider' && _selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one operational category niche!"), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    Map<String, dynamic> updatePayload = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'profilePic': _avatarUrlController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (_userRole == 'provider') {
      updatePayload['businessName'] = _businessNameController.text.trim();
      updatePayload['description'] = _descriptionController.text.trim();
      updatePayload['categories'] = _selectedCategories; 
      updatePayload['category'] = _selectedCategories.first; 
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(updatePayload);
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile fields successfully updated!"), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Write Exception: ${e.toString()}"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _avatarUrlController.dispose();
    _businessNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // 🎨 SMART IMAGE RENDER SEGMENT
  ImageProvider _getAvatarImageProvider(String source) {
    if (source.startsWith('data:image') && source.contains('base64,')) {
      try {
        String cleanBase64 = source.split('base64,')[1];
        return MemoryImage(base64Decode(cleanBase64));
      } catch (_) {
        return const NetworkImage('https://api.dicebear.com/7.x/bottts/png?seed=EventEasee');
      }
    } else if (source.isNotEmpty) {
      return NetworkImage(source);
    }
    return const NetworkImage('https://api.dicebear.com/7.x/bottts/png?seed=EventEasee');
  }

  @override
  Widget build(BuildContext context) {
    String currentEmail = FirebaseAuth.instance.currentUser?.email ?? 'No Active Session Email';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("My Account Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close_rounded : Icons.mode_edit_outline_rounded, color: const Color(0xFF6366F1)),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Column(
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              GestureDetector(
                                onTap: _isEditing ? _uploadProfileImageFromDevice : null,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF6366F1), width: 2),
                                  ),
                                  child: CircleAvatar(
                                    radius: 55,
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    backgroundImage: _getAvatarImageProvider(_avatarUrlController.text),
                                    child: _isEditing 
                                        ? Container(
                                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.4)),
                                            child: const Center(child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28)),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _userRole.toUpperCase(),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.w900, letterSpacing: 1),          
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(currentEmail, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 35),

                        TextFormField(
                          controller: _nameController,
                          enabled: _isEditing,
                          decoration: const InputDecoration(labelText: "Full Username/Identity", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline_rounded)),
                          validator: (value) => value == null || value.isEmpty ? "Name parameter cannot be empty" : null,
                        ),
                        const SizedBox(height: 20),

                        TextFormField(
                          controller: _phoneController,
                          enabled: _isEditing,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: "Phone Contact Sequence", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_android_rounded)),
                          validator: (value) => value == null || value.isEmpty ? "Contact path sequence required" : null,
                        ),
                        const SizedBox(height: 20),

                        if (_userRole == 'provider') ...[
                          const SizedBox(height: 24),
                          const Divider(height: 1),
                          const SizedBox(height: 24),
                          
                          TextFormField(
                            controller: _businessNameController,
                            enabled: _isEditing,
                            decoration: const InputDecoration(labelText: "Business/Agency Identity", border: OutlineInputBorder(), prefixIcon: Icon(Icons.storefront_rounded)),
                            validator: (value) => value == null || value.isEmpty ? "Business tracking name required" : null,
                          ),
                          const SizedBox(height: 24),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.category_outlined, size: 20, color: Color(0xFF64748B)),
                                    SizedBox(width: 8),
                                    Text("Operational Service Niches", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 8.0,
                                  children: _availableCategories.map((String cat) {
                                    bool isSelected = _selectedCategories.contains(cat);
                                    return FilterChip(
                                      label: Text(cat, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF475569))),
                                      selected: isSelected,
                                      selectedColor: const Color(0xFF6366F1),
                                      checkmarkColor: Colors.white,
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.transparent)),
                                      onSelected: _isEditing 
                                          ? (bool selectState) {
                                              setState(() {
                                                if (selectState) {
                                                  _selectedCategories.add(cat);
                                                } else {
                                                  _selectedCategories.remove(cat);
                                                }
                                              });
                                            }
                                          : null, 
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          TextFormField(
                            controller: _descriptionController,
                            enabled: _isEditing,
                            maxLines: 3,
                            decoration: const InputDecoration(labelText: "Services Portfolio Summary", border: OutlineInputBorder(), prefixIcon: Icon(Icons.description_outlined)),
                          ),
                        ],

                        if (_isEditing) ...[
                          const SizedBox(height: 35),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.save_as_rounded),
                            label: const Text("Save Updated Profile Data", style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: _saveProfileChanges,
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}