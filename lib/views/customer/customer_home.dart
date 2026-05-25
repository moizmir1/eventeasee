import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'post_event_screen.dart';
import 'view_bids_screen.dart'; // Make sure this import is here
import '../ticketing/create_ticketed_event.dart';
import '../ticketing/ticket_view.dart';
import '../ticketing/scanner_view.dart';
import '../ticketing/event_details_screen.dart';
import '../ticketing/guest_list_screen.dart'; 
import '../../services/auth_service.dart';

class CustomerHome extends StatelessWidget {
  const CustomerHome({super.key});

  // --- LOGIC: DELETE CONFIRMATION ---
  void _confirmDeletion(BuildContext context, String collection, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure? This will permanently remove the record and all associated data."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Successfully deleted")));
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- LOGIC: JOIN EVENT POPUP ---
  void _showJoinEventDialog(BuildContext context) {
    final idController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Event ID"),
        content: TextField(
          controller: idController,
          decoration: const InputDecoration(hintText: "e.g. EV-123456"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              String inputId = idController.text.trim();
              if (inputId.isEmpty) return;

              var query = await FirebaseFirestore.instance
                  .collection('ticketed_events')
                  .where('shortId', isEqualTo: inputId)
                  .limit(1)
                  .get();

              if (query.docs.isNotEmpty) {
                var doc = query.docs.first;
                Navigator.pop(context); 
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventDetailsScreen(
                      eventId: doc.id,
                      eventData: doc.data(),
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Event ID not found. Try again.")),
                );
              }
            }, 
            child: const Text("Find Event"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Event Easee"),
          actions: [
            IconButton(onPressed: () => AuthService().signOut(), icon: const Icon(Icons.logout)),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Hire Services", icon: Icon(Icons.work)),
              Tab(text: "Ticketing Hub", icon: Icon(Icons.confirmation_number)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- TAB 1: HIRE SERVICES ---
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PostEventScreen())),
                    label: const Text("Post New Requirement"),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('events')
                        .where('customerId', isEqualTo: currentUser?.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No service posts yet."));

                      return ListView.builder(
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          var doc = snapshot.data!.docs[index];
                          var data = doc.data() as Map<String, dynamic>;
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                            child: ListTile(
                              title: Text(data['title'] ?? 'No Title'),
                              subtitle: Text("Status: ${data['status'] ?? 'Pending'}"),
                              // FIX: Yahan onTap lagaya hai taake click karne par bids show hon
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ViewBidsScreen(eventId: doc.id),
                                  ),
                                );
                              },
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _confirmDeletion(context, 'events', doc.id),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

            // --- TAB 2: TICKETING HUB ---
            SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    _buildTicketingCard(
                      context,
                      title: "Create New Event",
                      subtitle: "Start selling tickets",
                      icon: Icons.add_box_outlined,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateTicketedEvent())),
                    ),
                    const SizedBox(height: 10),
                    _buildTicketingCard(
                      context,
                      title: "Get Ticket",
                      subtitle: "Join via Short ID",
                      icon: Icons.confirmation_number_outlined,
                      onTap: () => _showJoinEventDialog(context),
                    ),
                    const SizedBox(height: 10),
                    _buildTicketingCard(
                      context,
                      title: "Entrance Scanner",
                      subtitle: "Verify Guests",
                      icon: Icons.qr_code_scanner,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerView())),
                    ),
                    const SizedBox(height: 25),
                    const Text("My Ticketed Events", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('ticketed_events')
                          .where('organizerId', isEqualTo: currentUser?.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        return Column(
                          children: snapshot.data!.docs.map((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: const Icon(Icons.event, color: Colors.blue),
                                title: Text(data['eventName']),
                                subtitle: Text("ID: ${data['shortId']}"),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.people_outline),
                                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                                        builder: (context) => GuestListScreen(eventId: doc.id, eventName: data['eventName'])
                                      )),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _confirmDeletion(context, 'ticketed_events', doc.id),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketingCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.blue),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}