import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'post_event_screen.dart';
import 'view_bids_screen.dart'; 

// 🚀 FIXED SYSTEM IMPORTS: Exactly synchronized with your active files tree
import 'package:eventeasee/views/ticketing/create_ticketed_event.dart'; 
import 'package:eventeasee/views/ticketing/scanner_view.dart';
import 'package:eventeasee/views/ticketing/event_details_screen.dart';
import 'package:eventeasee/views/ticketing/guest_list_screen.dart'; 
import 'package:eventeasee/views/ticketing/ticket_receipt_screen.dart'; // 🚀 ADDED: Connecting receipt preview for dashboard links

import '../../services/auth_service.dart';
import 'package:eventeasee/views/profile/profile_screen.dart'; 
import 'package:eventeasee/services/notification_service.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  String _customerSortBy = 'newest'; 

  @override
  void initState() {
    super.initState();
    _initNotificationListener(); 
  }

  void _initNotificationListener() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    FirebaseFirestore.instance
        .collection('notifications')
        .where('targetUserId', isEqualTo: currentUser.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          try {
            await NotificationService.triggerInstantAlert(
              id: DateTime.now().millisecond,
              title: data['title'] ?? 'Alert Received',
              body: data['body'] ?? '',
            );
            await change.doc.reference.update({'isRead': true});
          } catch (_) {}
        }
      }
    });
  }

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
              if (context.mounted) Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Successfully deleted")));
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

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

              if (context.mounted) {
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
              }
            }, 
            child: const Text("Find Event"),
          ),
        ],
      ),
    );
  }

  void _showProviderReviewDialog(BuildContext context, String eventId, String providerId) {
    double selectedRatingStars = 5.0;
    final TextEditingController reviewCommentController = TextEditingController();
    bool isSavingReview = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Rate Service Experience", style: TextStyle(fontWeight: FontWeight.w100, fontSize: 16, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                const Text("Provide performance scores and evaluation notes below to complete order history parameters.", style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 20),
                
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          num starValue = index + 1;
                          return IconButton(
                            icon: Icon(
                              selectedRatingStars >= starValue ? Icons.star_rounded : Icons.star_border_rounded,
                              color: Colors.amber,
                              size: 34,
                            ),
                            onPressed: () => setDialogState(() => selectedRatingStars = starValue.toDouble()),
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text("${selectedRatingStars.toStringAsFixed(0)} / 5 Stars", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF6366F1))),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                const Text("Write a Description Note", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155))),
                const SizedBox(height: 8),
                
                TextFormField(
                  controller: reviewCommentController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Enter operational quality, coordination performance descriptions...",
                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                    fillColor: const Color(0xFFF8FAFC),
                    filled: true,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1))),
                  ),
                ),
                const SizedBox(height: 20),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isSavingReview ? null : () => Navigator.pop(dialogContext),
                      child: const Text("Later", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: isSavingReview ? null : () async {
                        if (reviewCommentController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Description review note is mandatory!"), backgroundColor: Colors.orangeAccent)
                          );
                          return;
                        }

                        setDialogState(() => isSavingReview = true);
                        try {
                          await FirebaseFirestore.instance.collection('reviews').add({
                            'eventId': eventId,
                            'providerId': providerId,
                            'customerId': FirebaseAuth.instance.currentUser?.uid ?? '',
                            'rating': selectedRatingStars,
                            'reviewText': reviewCommentController.text.trim(),
                            'timestamp': FieldValue.serverTimestamp(),
                          });

                          await FirebaseFirestore.instance.collection('events').doc(eventId).update({
                            'hasCustomerReviewed': true,
                          });

                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Review saved inside engine!"), backgroundColor: Color(0xFF10B981))
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSavingReview = false);
                        }
                      },
                      child: isSavingReview 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("Submit", style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text("Event Easee", style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          actions: [
            PopupMenuButton<String>(
              initialValue: _customerSortBy,
              icon: const Icon(Icons.filter_list_rounded, color: Color(0xFF6366F1), size: 26),
              tooltip: "Sort Requirements",
              onSelected: (String criteria) => setState(() => _customerSortBy = criteria),
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(value: 'newest', child: Row(children: [Icon(Icons.access_time_rounded, size: 18), SizedBox(width: 8), Text("Newest First")])),
                const PopupMenuItem(value: 'status', child: Row(children: [Icon(Icons.segment_rounded, size: 18), SizedBox(width: 8), Text("Sort by Status")])),
                const PopupMenuItem(value: 'title', child: Row(children: [Icon(Icons.sort_by_alpha_rounded, size: 18), SizedBox(width: 8), Text("Sort Alphabetically")])),
              ],
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('messages') 
                  .where('senderId', isNotEqualTo: currentUser?.uid)
                  .where('isRead', isEqualTo: false)
                  .snapshots(),
              builder: (context, badgeSnapshot) {
                int unreadMessagesCount = badgeSnapshot.hasData ? badgeSnapshot.data!.docs.length : 0;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.account_circle_outlined, size: 26, color: Color(0xFF6366F1)),
                      tooltip: "View Profile",
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                    ),
                    if (unreadMessagesCount > 0)
                      Positioned(
                        right: 4,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$unreadMessagesCount',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            IconButton(
              onPressed: () => AuthService().signOut(), 
              icon: const Icon(Icons.logout, color: Colors.redAccent),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFF6366F1),
            indicatorWeight: 3,
            labelColor: Color(0xFF6366F1),
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(text: "Hire Services", icon: Icon(Icons.work_outline_rounded)),
              Tab(text: "Ticketing Hub", icon: Icon(Icons.confirmation_number_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PostEventScreen())),
                    label: const Text("Post New Requirement", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('events')
                        .where('customerId', isEqualTo: currentUser?.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No custom service requirements posted yet.", style: TextStyle(color: Colors.grey, fontSize: 13)));

                      var myEvents = snapshot.data!.docs;

                      if (_customerSortBy == 'title') {
                        myEvents.sort((a, b) => (a['title'] ?? '').toString().compareTo((b['title'] ?? '').toString()));
                      } else if (_customerSortBy == 'status') {
                        myEvents.sort((a, b) => (a['status'] ?? '').toString().compareTo((b['status'] ?? '').toString()));
                      } else {
                        myEvents.sort((a, b) {
                          var aData = a.data() as Map<String, dynamic>;
                          var bData = b.data() as Map<String, dynamic>;
                          var aTime = aData.containsKey('createdAt') ? a['createdAt'] : null;
                          var bTime = bData.containsKey('createdAt') ? b['createdAt'] : null;
                          if (aTime == null) return 1;
                          if (bTime == null) return -1;
                          return bTime.compareTo(aTime);
                        });
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: myEvents.length,
                        itemBuilder: (context, index) {
                          var doc = myEvents[index];
                          var data = doc.data() as Map<String, dynamic>;
                          String status = data['status'] ?? 'open';
                          String projectStatus = data['projectStatus'] ?? 'ongoing';
                          bool isOpen = status.toLowerCase() == 'open';
                          bool isCompleted = projectStatus == 'completed';
                          bool hasReviewed = data['hasCustomerReviewed'] ?? false;
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  title: Row(
                                    children: [
                                      Expanded(child: Text(data['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isCompleted ? const Color(0xFFDBEAFE) : (isOpen ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7)),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          isCompleted ? "COMPLETED" : status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10, 
                                            fontWeight: FontWeight.w900, 
                                            color: isCompleted ? Colors.blue.shade700 : (isOpen ? const Color(0xFFD97706) : const Color(0xFF15803D))
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('bids')
                                        .where('eventId', isEqualTo: doc.id)
                                        .snapshots(),
                                    builder: (context, bidSnapshot) {
                                      int totalBids = bidSnapshot.hasData ? bidSnapshot.data!.docs.length : 0;
                                      
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6.0),
                                        child: Row(
                                          children: [
                                            Icon(Icons.gavel_rounded, size: 14, color: totalBids > 0 ? const Color(0xFF6366F1) : Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              "$totalBids Offers Received",
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: totalBids > 0 ? FontWeight.bold : FontWeight.normal,
                                                color: totalBids > 0 ? const Color(0xFF6366F1) : Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ViewBidsScreen(eventId: doc.id))),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                    onPressed: () => _confirmDeletion(context, 'events', doc.id),
                                  ),
                                ),

                                if (isCompleted) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                    child: Column(
                                      children: [
                                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                        const SizedBox(height: 10),
                                        if (!hasReviewed)
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: OutlinedButton.icon(
                                              icon: const Icon(Icons.star_rate_rounded, size: 14),
                                              label: const Text("Write Review", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFF6366F1), 
                                                side: const BorderSide(color: Color(0xFF6366F1), width: 1), 
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onPressed: () => _showProviderReviewDialog(context, doc.id, data['acceptedProviderId'] ?? ''),
                                            ),
                                          )
                                        else
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF0FDF4), 
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFBBF7D0), width: 0.5)
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 12),
                                                  SizedBox(width: 4),
                                                  Text("Reviewed ✔", style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 11)),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  )
                                ]
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

            SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Quick Actions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
                    
                    // ================= 🚀 NEW FEATURE: MY PURCHASED PASSES LEDGER HUB =================
                    const SizedBox(height: 25),
                    const Text("My Purchased Passes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 10),
                    
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('tickets')
                          .where('buyerId', isEqualTo: currentUser?.uid)
                          .snapshots(),
                      builder: (context, ticketSnapshot) {
                        if (ticketSnapshot.hasError) return const SizedBox();
                        if (!ticketSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                        if (ticketSnapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20), 
                              child: Text("Aap ne abhi tak koi pass buy nahi kiya.", style: TextStyle(fontSize: 12, color: Colors.grey))
                            )
                          );
                        }
                        
                        return Column(
                          children: ticketSnapshot.data!.docs.map((ticketDoc) {
                            var tData = ticketDoc.data() as Map<String, dynamic>;
                            String status = tData['status'] ?? 'pending';
                            
                            // Dynamic layout indicators for status matrices
                            Color badgeColor = const Color(0xFFFEF3C7);
                            Color txtColor = const Color(0xFFB45309);
                            if (status == 'verified') {
                              badgeColor = const Color(0xFFDCFCE7);
                              txtColor = const Color(0xFF166534);
                            } else if (status == 'declined') {
                              badgeColor = const Color(0xFFFEE2E2);
                              txtColor = const Color(0xFF991B1B);
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
                              child: ListTile(
                                leading: const CircleAvatar(backgroundColor: Color(0xFFF1F5F9), child: Icon(Icons.confirmation_number_outlined, color: Color(0xFF6366F1), size: 20)),
                                title: Text("Ticket ID: ${tData['ticketId'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                subtitle: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(6)),
                                      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, color: txtColor, fontWeight: FontWeight.bold)),
                                    )
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                                onTap: () {
                                  // 🚀 DYNAMIC ROUTE REDIRECTION STRAIGHT TO THE TICKET RECEIPT
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TicketReceiptScreen(
                                        eventData: {'shortId': 'EV-REC'},  // Structural placeholder logic layout
                                        ticketData: tData,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 25),
                    const Text("My Ticketed Events", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 10),
                    
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('ticketed_events')
                          .where('organizerId', isEqualTo: currentUser?.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return const SizedBox();
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        if (snapshot.data!.docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No live ticketing hubs active.", style: TextStyle(fontSize: 12, color: Colors.grey))));
                        
                        return Column(
                          children: snapshot.data!.docs.map((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
                              child: ListTile(
                                leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.event, color: Colors.blue, size: 20)),
                                title: Text(data['eventName'] ?? 'Untitled Ticketed Event', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                subtitle: Row(
                                  children: [
                                    Text("ID: ${data['shortId'] ?? 'N/A'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                      child: const Text("Live Ledger", style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                                    )
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.people_outline, color: Colors.blueGrey),
                                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                                        builder: (context) => GuestListScreen(eventId: doc.id)
                                      )),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 26, color: const Color(0xFF6366F1)),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}