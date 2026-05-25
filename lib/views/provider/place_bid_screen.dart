import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlaceBidScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final String? bidId;             // For editing existing bid
  final String? existingAmount;    // For auto-filling input on edit
  final String? existingMessage;   // For auto-filling input on edit

  const PlaceBidScreen({
    super.key, 
    required this.eventId, 
    required this.eventTitle,
    this.bidId,
    this.existingAmount,
    this.existingMessage,
  });

  @override
  State<PlaceBidScreen> createState() => _PlaceBidScreenState();
}

class _PlaceBidScreenState extends State<PlaceBidScreen> {
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Agar provider edit mode mein aaya hai, toh pichla data autofill ho jaye
    if (widget.bidId != null) {
      _amountController.text = widget.existingAmount ?? '';
      _messageController.text = widget.existingMessage ?? '';
    }
  }

  void _submitBid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _amountController.text.trim().isEmpty) return;

    // --- SMART BACKEND ROUTING ---
    // Agar bidId pehle se maujood hai toh usi document ko overwrite/update karenge, warna naya add hoga
    DocumentReference bidRef;
    if (widget.bidId != null) {
      bidRef = FirebaseFirestore.instance.collection('bids').doc(widget.bidId);
    } else {
      bidRef = FirebaseFirestore.instance.collection('bids').doc(); // Auto-generate ID
    }

    Map<String, dynamic> bidData = {
      'eventId': widget.eventId,
      'providerId': user.uid,
      'amount': double.tryParse(_amountController.text.trim()) ?? 0.0,
      'message': _messageController.text.trim(),
      'status': 'pending',
      'createdAt': DateTime.now(),
    };

    // Use .set with merge: true to avoid creating duplicate rows in Customer dashboard
    await bidRef.set(bidData, SetOptions(merge: true));

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.bidId != null ? "Bid Updated Successfully!" : "Bid Placed Successfully!"),
        ),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bidId != null ? "Edit Bid for ${widget.eventTitle}" : "Bid for ${widget.eventTitle}"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _amountController, 
              decoration: const InputDecoration(labelText: "Your Offer (Rs.)", border: OutlineInputBorder()), 
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _messageController, 
              maxLines: 3,
              decoration: const InputDecoration(labelText: "Message to Customer", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitBid, 
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(widget.bidId != null ? "Update My Bid" : "Submit Bid"),
            )
          ],
        ),
      ),
    );
  }
}