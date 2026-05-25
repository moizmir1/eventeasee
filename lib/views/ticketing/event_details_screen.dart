import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ticket_view.dart';

class EventDetailsScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const EventDetailsScreen({super.key, required this.eventId, required this.eventData});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  void _registerAndGetTicket() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || nameController.text.isEmpty) return;

    // 1. Create the unique ticket in the 'tickets' collection
    DocumentReference ticketRef = await FirebaseFirestore.instance.collection('tickets').add({
      'eventId': widget.eventId,
      'customerId': user.uid,
      'guestName': nameController.text,
      'guestPhone': phoneController.text,
      'eventName': widget.eventData['eventName'],
      'isScanned': false,
      'createdAt': DateTime.now(),
    });

    // 2. Send user to their new QR Ticket
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TicketView(
          ticketId: ticketRef.id,
          eventName: widget.eventData['eventName'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.eventData['eventName'])),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Description: ${widget.eventData['description']}", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            Text("Price: Rs. ${widget.eventData['price']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            const Divider(height: 40),
            const Text("Registration Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Full Name")),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Phone Number"), keyboardType: TextInputType.phone),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _registerAndGetTicket, 
                child: const Text("Confirm & Get Ticket"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}