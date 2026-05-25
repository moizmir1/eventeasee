import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderProfileScreen extends StatelessWidget {
  final String providerId;

  const ProviderProfileScreen({super.key, required this.providerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Provider Profile")),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(providerId).get(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (!userSnapshot.data!.exists) return const Center(child: Text("Profile not found."));

          var userData = userSnapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Profile Card
                Row(
                  children: [
                    CircleAvatar(radius: 40, child: Text(userData['name']?[0].toUpperCase() ?? 'P')),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userData['name'] ?? 'Provider Name', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        Text(userData['category'] ?? 'Event Specialist', style: const TextStyle(color: Colors.grey)),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 5),
                            Text(userData['rating']?.toString() ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 30),
                const Text("Previous Work & Portfolio Description:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(userData['bio'] ?? 'No bio description provided yet by the professional.', style: const TextStyle(color: Colors.black87)),
                const Divider(height: 40),
                const Text("Client Reviews", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                // Live Reviews List
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('reviews')
                      .where('providerId', isEqualTo: providerId)
                      .snapshots(),
                  builder: (context, reviewSnapshot) {
                    if (!reviewSnapshot.hasData) return const SizedBox();
                    if (reviewSnapshot.data!.docs.isEmpty) return const Text("No reviews yet. Be the first to hire them!");

                    return Column(
                      children: reviewSnapshot.data!.docs.map((reviewDoc) {
                        var rData = reviewDoc.data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Row(
                              children: List.generate(5, (index) => Icon(
                                Icons.star, 
                                size: 16, 
                                color: index < (rData['rating'] ?? 0) ? Colors.amber : Colors.grey[300]
                              )),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 5),
                                Text(rData['comment'] ?? ''),
Text(
  "- ${rData['customerName'] ?? 'Anonymous'}", 
  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic), // Fixed here
),                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                )
              ],
            ),
          );
        },
      ),
    );
  }
}