import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'place_bid_screen.dart'; 
import '../customer/chat_screen.dart'; 
import '../../services/auth_service.dart';

class ProviderHome extends StatelessWidget {
  const ProviderHome({super.key});

  // --- LOGIC: DELETE BID ---
  void _deleteBid(BuildContext context, String bidId) async {
    await FirebaseFirestore.instance.collection('bids').doc(bidId).delete();
    if (context.mounted) {
      Navigator.pop(context); // Close the options dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bid deleted successfully!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerId = FirebaseAuth.instance.currentUser?.uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Provider Dashboard"),
          actions: [
            IconButton(
              onPressed: () => AuthService().signOut(), 
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Available Leads", icon: Icon(Icons.list_alt)),
              Tab(text: "Accepted Jobs", icon: Icon(Icons.handshake_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- TAB 1: AVAILABLE LEADS ---
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .where('status', isEqualTo: 'open')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No new leads available."));

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      child: ListTile(
                        title: Text(data['title'] ?? 'No Title'),
                        subtitle: Text(data['description'] ?? 'No details'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        
                        onTap: () async {
                          // 1. Show loader
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(child: CircularProgressIndicator()),
                          );

                          try {
                            // 2. Query for existing bid
                            var existingBidQuery = await FirebaseFirestore.instance
                                .collection('bids')
                                .where('eventId', isEqualTo: doc.id)
                                .where('providerId', isEqualTo: providerId)
                                .limit(1)
                                .get();

                            if (context.mounted) Navigator.pop(context); // Pop loader

                            // 3. IF BID EXISTS: Show Edit / Delete Action Sheet
                            if (existingBidQuery.docs.isNotEmpty) {
                              var bidDoc = existingBidQuery.docs.first;
                              var bidData = bidDoc.data();

                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text("Manage Your Bid"),
                                    content: Text(
                                      "You have already placed a bid of Rs. ${bidData['amount']} for this lead. What would you like to do?",
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    actions: [
                                      // Action 1: Delete Bid
                                      TextButton.icon(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        label: const Text("Delete", style: TextStyle(color: Colors.red)),
                                        onPressed: () => _deleteBid(dialogContext, bidDoc.id),
                                      ),
                                      // Action 2: Edit Bid (Inside provider_home.dart)
TextButton.icon(
  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
  label: const Text("Edit"),
  onPressed: () {
    Navigator.pop(dialogContext); // Close popup
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceBidScreen(
          eventId: doc.id,
          eventTitle: data['title'] ?? 'No Title',
          bidId: bidDoc.id, // --- PASSING EXISTING BID ID ---
          existingAmount: bidData['amount']?.toString() ?? '', // Optional: purana rate show karne k liye
          existingMessage: bidData['message'] ?? '', // Optional: purana message show karne k liye
        ),
      ),
    );
  },
),
                                      // Action 3: Cancel/Close
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext),
                                        child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } else {
                              // 4. IF NO PREVIOUS BID: Open submission screen normally
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PlaceBidScreen(
                                      eventId: doc.id,
                                      eventTitle: data['title'] ?? 'No Title',
                                    ),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")),
                              );
                            }
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),

            // --- TAB 2: ACCEPTED JOBS ---
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .where('status', isEqualTo: 'accepted')
                  .where('acceptedProviderId', isEqualTo: providerId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No accepted jobs yet."));

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      color: Colors.green[50],
                      child: ListTile(
                        title: Text(data['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text("Status: Accepted ✔️", style: TextStyle(color: Colors.green)),
                        trailing: ElevatedButton.icon(
                          icon: const Icon(Icons.chat, size: 16),
                          label: const Text("Chat"),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  eventId: doc.id,
                                  providerId: providerId ?? '',
                                  providerName: "Client / Customer",
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}