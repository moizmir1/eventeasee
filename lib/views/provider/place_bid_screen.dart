import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eventeasee/services/notification_service.dart'; 

class PlaceBidScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final String? bidId;             
  final String? existingAmount;    
  final String? existingMessage;   

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
    if (widget.bidId != null) {
      _amountController.text = widget.existingAmount ?? '';
      _messageController.text = widget.existingMessage ?? '';
    }
  }

  void _submitBid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _amountController.text.trim().isEmpty) return;

    // Show inline circular loading overlay bounds
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      DocumentReference bidRef;
      if (widget.bidId != null) {
        bidRef = FirebaseFirestore.instance.collection('bids').doc(widget.bidId);
      } else {
        bidRef = FirebaseFirestore.instance.collection('bids').doc(); 
      }

      Map<String, dynamic> bidData = {
        'eventId': widget.eventId,
        'providerId': user.uid,
        'amount': double.tryParse(_amountController.text.trim()) ?? 0.0,
        'message': _messageController.text.trim(),
        'status': 'pending',
        'createdAt': DateTime.now(),
      };

      await bidRef.set(bidData, SetOptions(merge: true));

      // 📢 Fetch target parent event document parameters safely to capture target customerId
      var eventSnapshot = await FirebaseFirestore.instance.collection('events').doc(widget.eventId).get();
      String? customerId = eventSnapshot.data()?['customerId'];

      if (customerId != null) {
        // Pushes the live notification tracking doc straight into target user profile space
        await FirebaseFirestore.instance.collection('notifications').add({
          'targetUserId': customerId,
          'title': widget.bidId != null ? "Offer Updated! 📝" : "New Offer Received ⚡",
          'body': widget.bidId != null 
              ? "A vendor updated their quotation to Rs. ${_amountController.text.trim()} for your requirement."
              : "A verified service provider has submitted a new quotation for '${widget.eventTitle}'.",
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      // --- LOCAL BACKUP ALERTS AS TRACE RETAINED FOR DEVICE LOGS ---
      try {
        if (widget.bidId != null) {
          await NotificationService.triggerInstantAlert(
            id: 2, 
            title: "Bid Proposal Updated! 📝",
            body: "Your modified offer of Rs. ${_amountController.text.trim()} for '${widget.eventTitle}' has been updated.",
          );
        } else {
          await NotificationService.triggerInstantAlert(
            id: 3, 
            title: "Bid Proposal Dispatched! 🚀",
            body: "Your offer of Rs. ${_amountController.text.trim()} has been securely sent to the customer.",
          );
        }
      } catch (_) {}

      if (mounted) {
        Navigator.pop(context); // Close charging circular loading overlay indicators
        Navigator.pop(context); // Go secure backward routing to market index view
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.bidId != null ? "Bid Updated Successfully!" : "Bid Placed Successfully!"),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error routing submission: $e")));
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
        title: Text(widget.bidId != null ? "Edit Bid" : "Submit Proposal"),
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