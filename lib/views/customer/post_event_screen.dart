import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eventeasee/services/notification_service.dart'; 

class PostEventScreen extends StatefulWidget {
  const PostEventScreen({super.key});

  @override
  State<PostEventScreen> createState() => _PostEventScreenState();
}

class _PostEventScreenState extends State<PostEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locController = TextEditingController();

  final List<String> _categories = [
    'Photography',
    'Catering & Food',
    'Stage Decoration',
    'Sound System & DJ',
    'Event Planner',
    'Makeup Artist'
  ];
  
  String? _selectedCategory;

  void _submitEvent() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields and select a category")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String eventTitle = _titleController.text.trim();

        await FirebaseFirestore.instance.collection('events').add({
          'customerId': user.uid,
          'title': eventTitle,
          'description': _descController.text.trim(),
          'location': _locController.text.trim(),
          'category': _selectedCategory, 
          'status': 'open', 
          'projectStatus': 'ongoing',       
          'commissionStatus': 'pending',    
          'commissionScreenshotUrl': '',    
          'createdAt': Timestamp.now(),     
        });

        // 📢 --- REMOTE BROADCAST SYSTEM FOR TARGETED SERVICE VENDORS ---
        try {
          var providersSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'provider')
              .get();

          for (var pDoc in providersSnapshot.docs) {
            var providerData = pDoc.data();
            List<dynamic> categories = providerData['categories'] ?? [];
            String? primaryCategory = providerData['category'];

            // Match if provider shares this specific requested service category bounds
            if (categories.contains(_selectedCategory) || primaryCategory == _selectedCategory) {
              await FirebaseFirestore.instance.collection('notifications').add({
                'targetUserId': pDoc.id, 
                'title': "New Market Lead Live! 📢",
                'body': "A new client requirement for '$_selectedCategory' was just posted in Abbottabad!",
                'createdAt': FieldValue.serverTimestamp(),
                'isRead': false,
              });
            }
          }
        } catch (_) {}

        // Safe async check using mounted guard
        try {
          await NotificationService.triggerInstantAlert(
            id: 1, 
            title: "Requirement Live! 📢",
            body: "Your '$eventTitle' post is now open. Service providers can view and bid!",
          );
        } catch (_) {}
        
        if (mounted) {
          Navigator.pop(context); // Closes Loading Dialog
          Navigator.pop(context); // Goes back to Dashboard
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Text("Requirement Broadcasted to Market!", style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), 
      appBar: AppBar(
        title: const Text("Post Requirement", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              const Text(
                "Specify your event details below. Verified service vendors under the chosen category will instantly review your request.",
                style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 25),
              
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Event Title",
                  hintText: "e.g., Wedding Photography Needed",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? "Title is required" : null,
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: "Select Service Category Required",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
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
                validator: (value) => value == null ? "Please assign a category" : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _locController,
                decoration: const InputDecoration(
                  labelText: "Location",
                  hintText: "e.g., Abbottabad",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? "Location is required" : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Detailed Instructions / Requirements",
                  hintText: "State timings, package requirements, or expectations clearly...",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty ? "Please outline details" : null,
              ),
              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: _submitEvent,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(55),
                  backgroundColor: const Color(0xFF6366F1), 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Post Requirement", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}