import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'place_bid_screen.dart'; 
import '../customer/chat_screen.dart'; 
import '../../services/auth_service.dart';
import 'package:eventeasee/views/profile/profile_screen.dart'; 
import 'provider_analytics.dart';
import 'package:eventeasee/services/notification_service.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:flutter/foundation.dart' show Uint8List; 
import 'dart:convert'; 

// 🚀 FIXED SYSTEM IMPORT: Connected directly to your full screen post preview drossier
import 'package:eventeasee/views/provider/view_requirement_screen.dart';

class ProviderHome extends StatefulWidget {
  const ProviderHome({super.key});

  @override
  State<ProviderHome> createState() => _ProviderHomeState();
}

class _ProviderHomeState extends State<ProviderHome> {
  String _marketSortBy = 'newest'; 
  String _ordersSortBy = 'newest'; 

  @override
  void initState() {
    super.initState();
    _initProviderNotificationListener(); 
  }

  void _initProviderNotificationListener() {
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

  void _deleteBid(BuildContext context, String bidId) async {
    await FirebaseFirestore.instance.collection('bids').doc(bidId).delete();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bid rescinded safely."))
      );
    }
  }

  void _uploadFakeReceiptDialog(BuildContext context, String eventId) {
    bool isUploading = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Submit 10% Platform Fee", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Transfer the 10% commission to our corporate hub and select the payment verification snapshot directly from your device media storage:", 
                style: TextStyle(fontSize: 13, color: Colors.grey)
              ),
              const SizedBox(height: 20),
              if (isUploading)
                const Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFF6366F1)),
                    SizedBox(height: 12),
                    Text("Processing snapshot payload matrix...", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                  ],
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEEF2F6),
                    foregroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: const Text("Open Storage ", style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 20);
                    
                    if (image != null) {
                      setDialogState(() => isUploading = true);
                      try {
                        Uint8List imageBinaryBytes = await image.readAsBytes();
                        String base64PayloadString = base64Encode(imageBinaryBytes);
                        String completeBase64URI = "data:image/jpeg;base64,$base64PayloadString";

                        await FirebaseFirestore.instance.collection('events').doc(eventId).update({
                          'commissionStatus': 'submitted',
                          'commissionScreenshotUrl': completeBase64URI,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });

                        if (!mounted) return;
                        Navigator.pop(dialogContext);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Payment proof submitted succesfully! Wait for admin approval"), backgroundColor: Color(0xFF10B981))
                        );
                      } catch (err) {
                        setDialogState(() => isUploading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Memory Sync Exception: $err"), backgroundColor: Colors.redAccent)
                          );
                        }
                      }
                    }
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(dialogContext), 
              child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
            ),
          ],
        ),
      ),
    );
  }

  void _showBidManagementDialog(BuildContext context, String eventId, String eventTitle, QueryDocumentSnapshot bidDoc, String currentProviderId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.gavel_rounded, color: Color(0xFF6366F1), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      "Manage My Bid",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Current Offer: Rs. ${double.tryParse(bidDoc['amount'].toString())?.toStringAsFixed(0) ?? '0'}",
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text("Chat Now", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1), 
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext); 
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          eventId: eventId,
                          providerId: currentProviderId,
                          providerName: "Service Provider",
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text("Edit Bid", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    side: const BorderSide(color: Color(0xFF6366F1), width: 1.2),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlaceBidScreen(
                          eventId: eventId,
                          eventTitle: eventTitle,
                          bidId: bidDoc.id,
                          existingAmount: bidDoc['amount'].toString(),
                          existingMessage: bidDoc['message'],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text("Delete Bid", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _deleteBid(dialogContext, bidDoc.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final providerId = FirebaseAuth.instance.currentUser?.uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text("Provider Console", style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.analytics_outlined, size: 26, color: Color(0xFF6366F1)),
              tooltip: "Business Intelligence",
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProviderAnalytics())),
            ),
            IconButton(
              icon: const Icon(Icons.account_circle_outlined, size: 26, color: Color(0xFF6366F1)),
              tooltip: "My Dashboard Profile",
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
            ),
            IconButton(
              onPressed: () => AuthService().signOut(), 
              icon: const Icon(Icons.power_settings_new_rounded, color: Color(0xFFEF4444)),
              tooltip: "Sign Out",
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFF6366F1),
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
            labelColor: Color(0xFF6366F1),
            unselectedLabelColor: Color(0xFF94A3B8),
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(height: 50, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.explore_outlined, size: 18), SizedBox(width: 6), Text("Live Market")])),
              Tab(height: 50, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.handshake_outlined, size: 18), SizedBox(width: 6), Text("My Orders")])),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ================= TAB 1: LIVE MARKET FEED =================
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(providerId).get(),
              builder: (context, providerSnapshot) {
                if (providerSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var providerData = providerSnapshot.data?.data() as Map<String, dynamic>?;
                List<dynamic> providerCategories = providerData?['categories'] ?? [];
                if (providerCategories.isEmpty && providerData?['category'] != null) {
                  providerCategories = [providerData?['category']];
                }

                if (providerCategories.isEmpty) {
                  return const Center(child: Text("Please update your profile to select services.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)));
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('events')
                      .where('status', isEqualTo: 'open')
                      .where('category', whereIn: providerCategories)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No active market leads match your services right now.", style: TextStyle(color: Colors.grey)));

                    var docs = snapshot.data!.docs;

                    if (_marketSortBy == 'title') {
                      docs.sort((a, b) => (a['title'] ?? '').toString().compareTo((b['title'] ?? '').toString()));
                    } else {
                      docs.sort((a, b) {
                        var aData = a.data() as Map<String, dynamic>;
                        var bData = b.data() as Map<String, dynamic>;
                        var aTime = aData.containsKey('createdAt') ? a['createdAt'] : null;
                        var bTime = bData.containsKey('createdAt') ? b['createdAt'] : null;
                        if (aTime == null) return 1;
                        if (bTime == null) return -1;
                        return bTime.compareTo(aTime); 
                      });
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Available Leads (${docs.length})", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 13)),
                              PopupMenuButton<String>(
                                initialValue: _marketSortBy,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.sort_rounded, size: 16, color: Color(0xFF6366F1)),
                                      const SizedBox(width: 4),
                                      Text(_marketSortBy == 'newest' ? "Newest First" : "Alphabetical", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                    ],
                                  ),
                                ),
                                onSelected: (String criteria) => setState(() => _marketSortBy = criteria),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'newest', child: Text("Newest Leads")),
                                  const PopupMenuItem(value: 'title', child: Text("Sort Alphabetically")),
                                ],
                              )
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              var doc = docs[index];
                              var data = doc.data() as Map<String, dynamic>;

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF1F5F9))),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEEF2F6), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.flash_on_rounded, color: Color(0xFF6366F1))),
                                  title: Text(data['title'] ?? 'Untitled Event', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  subtitle: Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(data['description'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.grey))),
                                  trailing: const Icon(Icons.chevron_right_rounded),
                                  
                                  // ================= 🚀 REDIRECT PIPELINE RESTUCTURE HOOK =================
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ViewRequirementScreen(
                                          eventId: doc.id,
                                          eventData: data,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            // ================= TAB 2: ACTIVE CONTRACTS ORDERS =================
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .where('acceptedProviderId', isEqualTo: providerId)
                  .where('status', isEqualTo: 'accepted')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No contracts secured yet. Keep bidding!"));

                var orderDocs = snapshot.data!.docs;

                if (_ordersSortBy == 'title') {
                  orderDocs.sort((a, b) => (a['title'] ?? '').toString().compareTo((b['title'] ?? '').toString()));
                } else {
                  orderDocs.sort((a, b) {
                    var aData = a.data() as Map<String, dynamic>;
                    var bData = b.data() as Map<String, dynamic>;
                    var aTime = aData.containsKey('createdAt') ? a['createdAt'] : null;
                    var bTime = bData.containsKey('createdAt') ? b['createdAt'] : null;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return bTime.compareTo(aTime); 
                  });
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("My Active Contracts (${orderDocs.length})", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 13)),
                          PopupMenuButton<String>(
                            initialValue: _ordersSortBy,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                              child: Row(
                                children: [
                                  const Icon(Icons.filter_list_rounded, size: 16, color: Color(0xFF10B981)),
                                  const SizedBox(width: 4),
                                  Text(_ordersSortBy == 'newest' ? "Newest Projects" : "Alphabetical", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                ],
                              ),
                            ),
                            onSelected: (String criteria) => setState(() => _ordersSortBy = criteria),
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'newest', child: Text("Newest Assigned")),
                              const PopupMenuItem(value: 'title', child: Text("Sort Alphabetically")),
                            ],
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: orderDocs.length,
                        itemBuilder: (context, index) {
                          var doc = orderDocs[index];
                          var data = doc.data() as Map<String, dynamic>;

                          String pStatus = data['projectStatus'] ?? 'ongoing';
                          String commStatus = data['commissionStatus'] ?? 'pending';

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: pStatus == 'completed' ? const Color(0xFFF0FDF4) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: pStatus == 'completed' ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: pStatus == 'completed' ? Colors.blue : Colors.amber, borderRadius: BorderRadius.circular(8)),
                                      child: Text(pStatus.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Text("10% Fee System: ", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Text(
                                      commStatus == 'verified' 
                                          ? "VERIFIED ✔" 
                                          : commStatus == 'submitted' 
                                              ? "Pending VERIFICATION ⏳" 
                                              : "UNPAID ❌",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: commStatus == 'verified' ? Colors.green : commStatus == 'submitted' ? Colors.orange : Colors.red),
                                    )
                                  ],
                                ),
                                const Divider(height: 25),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.forum_rounded, size: 16),
                                      label: const Text("Chat"),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14)),
                                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ChatScreen(eventId: doc.id, providerId: providerId ?? '', providerName: "Client Portal"))),
                                    ),
                                    if (commStatus == 'pending')
                                      TextButton.icon(
                                        icon: const Icon(Icons.upload_file_rounded),
                                        label: const Text("Share Screenshot"),
                                        onPressed: () => _uploadFakeReceiptDialog(context, doc.id),
                                      ),
                                    if (pStatus != 'completed')
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                        label: const Text("Complete"),
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14)),
                                        onPressed: () async {
                                          await FirebaseFirestore.instance.collection('events').doc(doc.id).update({'projectStatus': 'completed'});
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Project lifecycle marked as completed safely!"), backgroundColor: Colors.green));
                                        },
                                      )
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}