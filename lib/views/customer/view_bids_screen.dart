import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'provider_profile_screen.dart'; 
import 'chat_screen.dart';             

class ViewBidsScreen extends StatelessWidget {
  final String eventId;

  const ViewBidsScreen({super.key, required this.eventId});

  void _acceptBid(BuildContext context, String bidId, String providerId) async {
    await FirebaseFirestore.instance.collection('events').doc(eventId).update({
      'status': 'accepted',
      'acceptedProviderId': providerId,
    });

    await FirebaseFirestore.instance.collection('bids').doc(bidId).update({
      'status': 'accepted',
    });

    // Note: Navigator.pop hata diya taake customer usi screen par live update dekh sakay
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bid Accepted! Service Provider will contact you.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Received Bids")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bids')
            .where('eventId', isEqualTo: eventId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No bids received yet."));

          // --- FIXED LOGIC: CHECK IF ANY BID IS ALREADY ACCEPTED FOR THIS EVENT ---
          bool isAnyBidAccepted = snapshot.data!.docs.any((doc) {
            var bidData = doc.data() as Map<String, dynamic>;
            return bidData['status'] == 'accepted';
          });

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String providerId = data['providerId'] ?? '';
              bool isThisBidAccepted = data['status'] == 'accepted';

              return Card(
                color: isThisBidAccepted ? Colors.green[50] : null,
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text("Offer: Rs. ${data['amount']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        subtitle: Text(data['message'] ?? 'No message'),
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // BUTTON 1: VIEW PROFILE
                          TextButton.icon(
                            icon: const Icon(Icons.person_outline),
                            label: const Text("View Profile"),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProviderProfileScreen(providerId: providerId),
                              ),
                            ),
                          ),
                          // BUTTON 2: CHAT BEFORE ACCEPTING
                          TextButton.icon(
                            icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                            label: const Text("Message"),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  eventId: eventId,
                                  providerId: providerId,
                                  providerName: "Service Provider", 
                                ),
                              ),
                            ),
                          ),
                          // --- OPTIMIZED BUTTON 3: CONDITIONAL ACCEPTANCE VIEW ---
                          isThisBidAccepted
                              ? const Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green),
                                    SizedBox(width: 4),
                                    Text("Accepted", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                  ],
                                )
                              : (isAnyBidAccepted 
                                  ? const Text("Closed", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
                                  : ElevatedButton(
                                      onPressed: () => _acceptBid(context, doc.id, providerId),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                      child: const Text("Accept"),
                                    )),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}