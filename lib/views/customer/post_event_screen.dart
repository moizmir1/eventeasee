import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostEventScreen extends StatefulWidget {
  const PostEventScreen({super.key});

  @override
  State<PostEventScreen> createState() => _PostEventScreenState();
}

class _PostEventScreenState extends State<PostEventScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locController = TextEditingController();

  void _submitEvent() async {
    // 1. Check if the user typed anything
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a title")),
      );
      return;
    }

    // 2. Show a loading circle
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('events').add({
          'customerId': user.uid,
          'title': _titleController.text,
          'description': _descController.text,
          'location': _locController.text,
          'status': 'open',
          'createdAt': DateTime.now(),
        });
        
        // 3. Close loading circle and go back
        Navigator.pop(context); // Closes Loading Dialog
        Navigator.pop(context); // Goes back to Dashboard
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Event Posted Successfully!")),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading circle
      print("Error posting event: $e"); // Check VS Code Debug Console for this
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Post Event Requirement")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: "Event Title (e.g. Wedding Photography)")),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: "Details (e.g. Need 5 hours coverage)")),
            TextField(controller: _locController, decoration: const InputDecoration(labelText: "Location (e.g. Abbottabad)")),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _submitEvent, child: const Text("Post Requirement"))
          ],
        ),
      ),
    );
  }
}