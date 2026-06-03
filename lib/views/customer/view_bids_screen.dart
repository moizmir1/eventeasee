import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'provider_profile_screen.dart'; 
import 'chat_screen.dart';            

class ViewBidsScreen extends StatefulWidget {
  final String eventId;

  const ViewBidsScreen({super.key, required this.eventId});

  @override
  State<ViewBidsScreen> createState() => _ViewBidsScreenState();
}

class _ViewBidsScreenState extends State<ViewBidsScreen> {
  String _bidSortBy = 'newest'; 

  // --- ATOMIC BATCH TRANSACTION ENGINE TO PREVENT DB MISMATCH ---
  void _acceptBid(BuildContext context, String bidId, String providerId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Initialize atomic structural writing sequence
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Lock state indicators inside parent event document reference
      DocumentReference eventRef = FirebaseFirestore.instance.collection('events').doc(widget.eventId);
      batch.update(eventRef, {
        'status': 'accepted',
        'acceptedProviderId': providerId,
        'projectStatus': 'ongoing',       
        'commissionStatus': 'pending',    
      });

      // 2. Set status mapping flag configurations onto winning bid document reference
      DocumentReference winningBidRef = FirebaseFirestore.instance.collection('bids').doc(bidId);
      batch.update(winningBidRef, {
        'status': 'accepted',
      });

      // 3. Automatically query and reject secondary floating offers via transaction mapping
      var otherBids = await FirebaseFirestore.instance
          .collection('bids')
          .where('eventId', isEqualTo: widget.eventId)
          .get();

      for (var bDoc in otherBids.docs) {
        if (bDoc.id != bidId) {
          batch.update(bDoc.reference, {'status': 'rejected'});
        }
      }

      // 4. Register remote data trigger notification directly into atomic pipeline array
      DocumentReference notificationRef = FirebaseFirestore.instance.collection('notifications').doc();
      batch.set(notificationRef, {
        'targetUserId': providerId, 
        'title': "Deal Secured! 🎉",
        'body': "Congratulations! The client approved your quotation. Chat system is now active.",
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Commit all system schema shifts synchronously onto server
      await batch.commit();

      if (context.mounted) {
        Navigator.pop(context); // Close loading overlay indicators safely
        Navigator.pop(context); // Pop securely backward routing to dashboard index view
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text("Deal Secured Successfully!", style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error binding contract architecture: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), 
      appBar: AppBar(
        title: const Text("Received Proposals", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            initialValue: _bidSortBy,
            icon: const Icon(Icons.swap_vert_rounded, color: Color(0xFF6366F1), size: 26),
            tooltip: "Filter Offers Budget Matrix",
            onSelected: (criteria) => setState(() => _bidSortBy = criteria),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'newest', child: Text("Received: Newest First")),
              const PopupMenuItem(value: 'lowest_price', child: Text("Budget: Lowest First")),
              const PopupMenuItem(value: 'highest_price', child: Text("Budget: Highest First")),
            ],
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bids')
            .where('eventId', isEqualTo: widget.eventId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var bidDocuments = snapshot.data!.docs;
          
          if (bidDocuments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.gavel_rounded, size: 70, color: Colors.grey[300]),
                  const SizedBox(height: 15),
                  const Text(
                    "No proposals submitted yet", 
                    style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          // Sorting processing operations mapping arrays smoothly on client side runs
          if (_bidSortBy == 'lowest_price') {
            bidDocuments.sort((a, b) => (double.tryParse(a['amount'].toString()) ?? 0.0).compareTo(double.tryParse(b['amount'].toString()) ?? 0.0));
          } else if (_bidSortBy == 'highest_price') {
            bidDocuments.sort((a, b) => (double.tryParse(b['amount'].toString()) ?? 0.0).compareTo(double.tryParse(a['amount'].toString()) ?? 0.0));
          } else {
            bidDocuments.sort((a, b) {
              var aTime = (a.data() as Map<String, dynamic>).containsKey('createdAt') ? a['createdAt'] : null;
              var bTime = (b.data() as Map<String, dynamic>).containsKey('createdAt') ? b['createdAt'] : null;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });
          }

          bool isAnyBidAccepted = bidDocuments.any((doc) {
            var bidData = doc.data() as Map<String, dynamic>;
            return bidData['status'] == 'accepted';
          });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: bidDocuments.length,
            itemBuilder: (context, index) {
              var doc = bidDocuments[index];
              var data = doc.data() as Map<String, dynamic>;
              String providerId = data['providerId'] ?? '';
              bool isThisBidAccepted = data['status'] == 'accepted';

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isThisBidAccepted ? const Color(0xFF10B981) : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isThisBidAccepted 
                          ? const Color(0xFF10B981).withOpacity(0.1) 
                          : const Color(0xFF0F172A).withOpacity(0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    children: [
                      if (isThisBidAccepted)
                        Container(
                          height: 6,
                          width: double.infinity,
                          color: const Color(0xFF10B981),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isThisBidAccepted ? const Color(0xFFD1FAE5) : const Color(0xFFEEF2F6),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        Icons.payments_rounded, 
                                        color: isThisBidAccepted ? const Color(0xFF10B981) : const Color(0xFF6366F1)
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("Offered Budget", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text("Rs. ${data['amount']}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isThisBidAccepted ? const Color(0xFF065F46) : const Color(0xFF1E293B))),
                                      ],
                                    ),
                                  ],
                                ),
                                if (isThisBidAccepted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(30)),
                                    child: const Text("ACCEPTED ✔", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                  )
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                data['message'] ?? 'No custom message added.',
                                style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.5, fontStyle: FontStyle.italic),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                InkWell(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => ProviderProfileScreen(providerId: providerId)),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.person_outline_rounded, color: Color(0xFF475569)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                InkWell(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        eventId: widget.eventId,
                                        providerId: providerId,
                                        providerName: "Service Provider",
                                      ),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFC7D2FE)),
                                      color: const Color(0xFFEEF2F6),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF6366F1)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (!isThisBidAccepted) 
                                  Expanded(
                                    child: isAnyBidAccepted
                                        ? const Center(child: Text("Closed", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))
                                        : ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF6366F1),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                            ),
                                            onPressed: () => _acceptBid(context, doc.id, providerId),
                                            child: const Text("Accept Offer", style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                  ),
                              ],
                            )
                          ],
                        ),
                      ),
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