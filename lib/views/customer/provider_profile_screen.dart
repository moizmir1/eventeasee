import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderProfileScreen extends StatelessWidget {
  final String providerId;

  const ProviderProfileScreen({super.key, required this.providerId});

  // 🚀 HELPER METHOD: Fetches reviewer name dynamically from the users collection using customerId
  Future<String> _getCustomerName(String customerId) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        var data = userDoc.data() as Map<String, dynamic>;
        return data['name'] ?? 'Anonymous Client';
      }
    } catch (_) {}
    return 'Anonymous Client';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Provider Profile"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(providerId).get(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (!userSnapshot.data!.exists) return const Center(child: Text("Profile not found."));

          var userData = userSnapshot.data!.data() as Map<String, dynamic>;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reviews')
                .where('providerId', isEqualTo: providerId)
                .snapshots(),
            builder: (context, reviewSnapshot) {
              double avgRating = 0.0;
              var reviewDocs = reviewSnapshot.hasData ? reviewSnapshot.data!.docs : [];
              
              if (reviewDocs.isNotEmpty) {
                double totalScoreSum = 0;
                for (var doc in reviewDocs) {
                  var rData = doc.data() as Map<String, dynamic>;
                  totalScoreSum += double.tryParse(rData['rating']?.toString() ?? '0.0') ?? 0.0;
                }
                avgRating = totalScoreSum / reviewDocs.length;
              } else {
                avgRating = double.tryParse(userData['averageRating']?.toString() ?? userData['rating']?.toString() ?? '0.0') ?? 0.0;
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Profile Header Card Block
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40, 
                          backgroundColor: const Color(0x146366F1), 
                          child: Text(
                            userData['name']?[0].toUpperCase() ?? 'P', 
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))
                          )
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(userData['name'] ?? 'Provider Name', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              Text(userData['category'] ?? 'Event Specialist', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                              const SizedBox(height: 4),
                              
                              // ⭐ DYNAMIC STAR RATING GENERATOR HEADER
                              Row(
                                children: [
                                  ...List.generate(5, (index) {
                                    return Icon(
                                      index < avgRating.floor()
                                          ? Icons.star_rounded
                                          : (index < avgRating && avgRating % 1 != 0)
                                              ? Icons.star_half_rounded
                                              : Icons.star_border_rounded,
                                      color: const Color(0xFFFBBF24),
                                      size: 18,
                                    );
                                  }),
                                  const SizedBox(width: 6),
                                  Text(
                                    avgRating > 0 ? avgRating.toStringAsFixed(1) : "0.0", 
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569), fontSize: 13)
                                  ),
                                ],
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Text("Previous Work & Portfolio Description:", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    const SizedBox(height: 8),
                    Text(userData['bio'] ?? userData['description'] ?? 'No bio description provided yet by the professional.', style: const TextStyle(color: Color(0xFF334155), height: 1.4)),
                    const Divider(height: 40),
                    const Text("Client Reviews", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    const SizedBox(height: 12),

                    if (reviewDocs.isEmpty)
                      const Text("No reviews yet. Be the first to hire them!", style: TextStyle(color: Colors.grey, fontSize: 13))
                    else
                      Column(
                        children: reviewDocs.map((reviewDoc) {
                          var rData = reviewDoc.data() as Map<String, dynamic>;
                          double rScore = double.tryParse(rData['rating']?.toString() ?? '5.0') ?? 5.0;
                          
                          // 🚀 MATCHED DATA KEY: Extracts the exact review content safely using 'reviewText'
                          String reviewContent = rData['reviewText'] ?? 'No written feedback details left.';
                          String customerId = rData['customerId'] ?? '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E8F0))),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(14),
                              title: Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Row(
                                  children: List.generate(5, (index) => Icon(
                                    Icons.star_rounded, 
                                    size: 16, 
                                    color: index < rScore.floor() ? const Color(0xFFFBBF24) : Colors.grey[300]
                                  )),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reviewContent, 
                                    style: const TextStyle(color: Color(0xFF334155), fontSize: 13, height: 1.3)
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  // 🚀 DYNAMIC REVIEWER NAME RESOLVER
                                  FutureBuilder<String>(
                                    future: _getCustomerName(customerId),
                                    builder: (context, nameSnapshot) {
                                      String clientName = nameSnapshot.data ?? "Loading...";
                                      return Text(
                                        "- $clientName", 
                                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey, fontWeight: FontWeight.bold),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}