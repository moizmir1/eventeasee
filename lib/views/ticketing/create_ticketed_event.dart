import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:flutter/services.dart'; // Needed for Clipboard
class CreateTicketedEvent extends StatefulWidget {
  const CreateTicketedEvent({super.key});

  @override
  State<CreateTicketedEvent> createState() => _CreateTicketedEventState();
}

class _CreateTicketedEventState extends State<CreateTicketedEvent> {
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final descController = TextEditingController();

 void _createEvent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || nameController.text.isEmpty) return;

    // 1. Generate a 6-digit short ID (e.g., EVENT-7429)
    String shortId = "EV-${Random().nextInt(900000) + 100000}";

    // 2. Save to Firestore
    DocumentReference docRef = await FirebaseFirestore.instance.collection('ticketed_events').add({
      'organizerId': user.uid,
      'eventName': nameController.text,
      'price': double.tryParse(priceController.text) ?? 0.0,
      'description': descController.text,
      'shortId': shortId, // We save this for easy searching
      'createdAt': DateTime.now(),
    });

    // 3. Show Success Dialog with Copy Button
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Event is Live! 🚀"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Your Short Event ID:"),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(shortId, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shortId));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID Copied!")));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); }, 
            child: const Text("Done")
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Ticketed Event")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Event Name")),
            TextField(controller: priceController, decoration: const InputDecoration(labelText: "Price per Ticket (Rs.)"), keyboardType: TextInputType.number),
            TextField(controller: descController, decoration: const InputDecoration(labelText: "Details")),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _createEvent, child: const Text("Launch Event")),
          ],
        ),
      ),
    );
  }
}