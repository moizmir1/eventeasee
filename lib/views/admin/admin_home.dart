import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show Uint8List;

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _currentIndex = 0;
  
  // 🚀 SUB-DIVISION CONTROL PARAMETER FOR USER PANEL
  String _activeUserRoleFilter = 'customer'; 

  // --- CONTROL ACTION: TOGGLE BLOCK ACCOUNT STATUS ---
  Future<void> _toggleUserBlock(String uid, bool currentBlockState) async {
    Map<String, dynamic> blockPayload = {
      'isBlocked': !currentBlockState,
    };

    if (currentBlockState == true) {
      blockPayload['leakageAttempts'] = 0;
      blockPayload['banReason'] = FieldValue.delete(); 
    } else {
      blockPayload['banReason'] = 'Suspended manually by Administrator action boundary.';
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).update(blockPayload);
  }

  // --- CONTROL ACTION: HARD REGISTRY PURGE ---
  void _confirmUserDeletion(BuildContext context, String uid, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete Account"),
        content: Text("Are you sure you want to permanently purge $name from the registry?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(uid).delete();
              if (context.mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account deleted successfully")));
            },
            child: const Text("Delete permanently"),
          ),
        ],
      ),
    );
  }

  // 💎 OVERLAY UTILITY DISPLAYING RAW CODES OR REMOTE URL SLIPS AT THE SPOT
  void _showReceiptVisualOverlay(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450, maxHeight: 550),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Payment Audit Receipt", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: imageUrl.startsWith('data:image') && imageUrl.contains('base64,')
                      ? Image.memory(base64Decode(imageUrl.split('base64,')[1]), fit: BoxFit.contain, width: double.infinity)
                      : Image.network(imageUrl, fit: BoxFit.contain, width: double.infinity, 
                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, size: 50, color: Colors.grey))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _currentIndex == 0 
              ? "Admin: Governance Board" 
              : _currentIndex == 1 
                  ? "Admin: User Panel" 
                  : "Admin: Revenue Stats",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => AuthService().signOut(),
            icon: const Icon(Icons.logout, color: Colors.redAccent),
          )
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // ================= TAB 1: SCREENSHOT AUDITS SECTIONS RESTRUCTURING =================
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('events').where('status', isEqualTo: 'accepted').snapshots(),
            builder: (context, eventSnapshot) {
              if (!eventSnapshot.hasData) return const Center(child: CircularProgressIndicator());

              var eventDocs = eventSnapshot.data!.docs;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('bids').where('status', isEqualTo: 'accepted').snapshots(),
                builder: (context, bidsSnapshot) {
                  if (!bidsSnapshot.hasData) return const Center(child: CircularProgressIndicator());

                  var bidDocs = bidsSnapshot.data!.docs;

                  var pendingVerifications = eventDocs.where((e) {
                    var d = e.data() as Map<String, dynamic>;
                    return (d['commissionStatus'] ?? 'pending') == 'submitted';
                  }).toList();

                  var verifiedClosedCases = eventDocs.where((e) {
                    var d = e.data() as Map<String, dynamic>;
                    return (d['projectStatus'] ?? 'ongoing') == 'completed' && (d['commissionStatus'] ?? 'pending') == 'verified';
                  }).toList();

                  var uncompletedUnpaidLogs = eventDocs.where((e) {
                    var d = e.data() as Map<String, dynamic>;
                    return (d['projectStatus'] ?? 'ongoing') != 'completed' && (d['commissionStatus'] ?? 'pending') == 'pending';
                  }).toList();

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSummaryStripBanner(verifiedClosedCases.length, pendingVerifications.length, uncompletedUnpaidLogs.length),
                      const SizedBox(height: 24),

                      _buildSegmentLabel("Pending Approvals ⏳", "${pendingVerifications.length} uploads awaiting evaluation", Colors.orangeAccent),
                      const SizedBox(height: 10),
                      _buildRestructuredListView(pendingVerifications, bidDocs, true),
                      const SizedBox(height: 32),

                      _buildSegmentLabel("Verified & Closed Contracts 🏆", "${verifiedClosedCases.length} assignments fully completed", const Color(0xFF10B981)),
                      const SizedBox(height: 10),
                      _buildRestructuredListView(verifiedClosedCases, bidDocs, false),
                      const SizedBox(height: 32),

                      _buildSegmentLabel("Incomplete & Unpaid Tracker ❌", "${uncompletedUnpaidLogs.length} matching entries remaining", const Color(0xFFEF4444)),
                      const SizedBox(height: 10),
                      _buildRestructuredListView(uncompletedUnpaidLogs, bidDocs, false),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              );
            },
          ),

          // ================= TAB 2: USER REGISTRY & SUB-DIVIDED CONTROL PANEL =================
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No users registered yet."));

              var allUsers = snapshot.data!.docs;
              
              var filteredUsers = allUsers.where((u) {
                var role = ((u.data() as Map<String, dynamic>)['role'] ?? 'customer').toString().toLowerCase();
                return role == _activeUserRoleFilter;
              }).toList();

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Row(
                      children: [
                        _buildSubDivisionChip("Customers Matrix", 'customer', Icons.person_outline_rounded),
                        const SizedBox(width: 12),
                        _buildSubDivisionChip("Service Providers", 'provider', Icons.storefront_rounded),
                      ],
                    ),
                  ),
                  
                  Expanded(
                    child: filteredUsers.isEmpty
                        ? Center(child: Text("No indexed ${_activeUserRoleFilter}s tracked in system registry.", style: const TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              var doc = filteredUsers[index];
                              var userData = doc.data() as Map<String, dynamic>;
                              String uid = doc.id;
                              String name = userData['name'] ?? 'Anonymous User';
                              String email = userData['email'] ?? 'No email provided'; // 🚀 EMAIL EXTRACTED
                              String role = userData['role'] ?? 'Customer';
                              bool isBlocked = userData['isBlocked'] ?? false;
                              String banReason = userData['banReason'] ?? '';

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12), 
                                  side: BorderSide(color: isBlocked ? Colors.red.withOpacity(0.4) : const Color(0xFFE2E8F0), width: isBlocked ? 1.5 : 1)
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isBlocked ? Colors.red.withOpacity(0.1) : const Color(0xFF6366F1).withOpacity(0.1),
                                    child: Icon(Icons.person, color: isBlocked ? Colors.red : const Color(0xFF6366F1), size: 20),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      if (isBlocked) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                                          child: const Text("BANNED", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                        )
                                      ]
                                    ],
                                  ),
                                  // 🚀 UPDATED SUBTITLE TO SHOW EMAIL AND ROLE
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        const SizedBox(height: 2),
                                        Text("Role: ${role.toUpperCase()}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF6366F1))),
                                        if (isBlocked && banReason.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text("Reason: $banReason", style: const TextStyle(fontSize: 10, color: Colors.red, fontStyle: FontStyle.italic)),
                                        ]
                                      ],
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(isBlocked ? Icons.block_flipped : Icons.verified_user_rounded, color: isBlocked ? Colors.red : Colors.green),
                                        tooltip: isBlocked ? "Unblock Account" : "Block Account",
                                        onPressed: () => _toggleUserBlock(uid, isBlocked),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_sweep_rounded, color: Colors.grey),
                                        tooltip: "Hard Purge Account",
                                        onPressed: () => _confirmUserDeletion(context, uid, name),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),

          // ================= TAB 3: BUSINESS REVENUE STATS PANEL =================
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, userSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('tickets').snapshots(),
                builder: (context, ticketSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('bids').where('status', isEqualTo: 'accepted').snapshots(),
                    builder: (context, bidsSnap) {
                      if (!userSnap.hasData || !ticketSnap.hasData || !bidsSnap.hasData) return const Center(child: CircularProgressIndicator());

                      int totalUsers = userSnap.data!.docs.length;
                      int totalTicketsSold = ticketSnap.data!.docs.length;

                      double grossTicketRevenue = 0.0;
                      for (var doc in ticketSnap.data!.docs) {
                        var tData = doc.data() as Map<String, dynamic>;
                        var priceVal = tData['price'] ?? 0;
                        grossTicketRevenue += double.tryParse(priceVal.toString()) ?? 0.0;
                      }

                      double totalVerifiedCommissions = 0.0;
                      for (var doc in bidsSnap.data!.docs) {
                        var bData = doc.data() as Map<String, dynamic>;
                        if (bData['commissionLock'] == 'verified') {
                          double dealVal = double.tryParse(bData['amount'].toString()) ?? 0.0;
                          totalVerifiedCommissions += (dealVal * 0.1);
                        }
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("System Analytics Metrics", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 16),
                            _buildMetricCard("TOTAL INDEXED USERS", totalUsers.toString(), Icons.people_alt_rounded, const Color(0xFF6366F1)),
                            const SizedBox(height: 12),
                            _buildMetricCard("TICKETS RESERVED", totalTicketsSold.toString(), Icons.confirmation_number_rounded, const Color(0xFFF59E0B)),
                            const SizedBox(height: 12),
                            _buildMetricCard("TICKET HUB GROSS REVENUE", "Rs. ${grossTicketRevenue.toStringAsFixed(0)}", Icons.account_balance_wallet_rounded, const Color(0xFF10B981)),
                            const SizedBox(height: 12),
                            _buildMetricCard("COLLECTED 10% PLATFORM COMMISSIONS", "Rs. ${totalVerifiedCommissions.toStringAsFixed(0)}", Icons.gavel_rounded, const Color(0xFF3B82F6)),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF6366F1),
        unselectedItemColor: Colors.blueGrey, 
        backgroundColor: Colors.white,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.percent_rounded), label: "Commissions Board"),
          BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_rounded), label: "User Control"),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: "Revenue Stats"),
        ],
      ),
    );
  }

  // --- SUB-DIVISION INTERACTIVE CHIP ENGINE CREATION ---
  Widget _buildSubDivisionChip(String title, String roleCode, IconData icon) {
    bool isSelected = _activeUserRoleFilter == roleCode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeUserRoleFilter = roleCode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                title, 
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentLabel(String title, String meta, Color leftColor) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: leftColor, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
            Text(meta, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        )
      ],
    );
  }

  Widget _buildRestructuredListView(List<DocumentSnapshot> eventList, List<QueryDocumentSnapshot> bidDocs, bool isPendingQueue) {
    if (eventList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: const Center(child: Text("No operational records match criteria entries inside current view framework.", style: TextStyle(color: Colors.grey, fontSize: 12))),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: eventList.length,
      itemBuilder: (context, index) {
        var doc = eventList[index];
        var data = doc.data() as Map<String, dynamic>;
        String screenshotUriString = data['commissionScreenshotUrl'] ?? '';

        var matchingBidList = bidDocs.where((b) => (b.data() as Map<String, dynamic>)['eventId'] == doc.id).toList();
        double totalAmount = matchingBidList.isNotEmpty ? (double.tryParse(matchingBidList.first['amount'].toString()) ?? 0.0) : 0.0;
        double commission = totalAmount * 0.10;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(data['title'] ?? 'Contract Contract', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)))),
                  if (screenshotUriString.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () => _showReceiptVisualOverlay(context, screenshotUriString),
                      icon: const Icon(Icons.receipt_long_rounded, size: 12),
                      label: const Text("View Slip", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF1F5F9), foregroundColor: const Color(0xFF6366F1), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                    )
                ],
              ),
              const SizedBox(height: 4),
              Text("Budget: Rs. ${totalAmount.toStringAsFixed(0)} | 10% Fee: Rs. ${commission.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Lifecycle: ${(data['projectStatus'] ?? 'ongoing').toString().toUpperCase()}", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: data['projectStatus'] == 'completed' ? Colors.blue : Colors.amber)),
                      Text("Fee Status: ${(data['commissionStatus'] ?? 'pending').toString().toUpperCase()}", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: data['commissionStatus'] == 'verified' ? Colors.green : data['commissionStatus'] == 'submitted' ? Colors.orange : Colors.red)),
                    ],
                  ),
                  if (isPendingQueue)
                    Row(
                      children: [
                        TextButton(
                          onPressed: () async {
                            await FirebaseFirestore.instance.collection('events').doc(doc.id).update({'commissionStatus': 'pending', 'commissionScreenshotUrl': ''});
                          },
                          child: const Text("Reject", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 4),
                        ElevatedButton(
                          onPressed: () async {
                            await FirebaseFirestore.instance.collection('events').doc(doc.id).update({'commissionStatus': 'verified'});
                            for (var bDoc in matchingBidList) {
                              await bDoc.reference.update({'commissionLock': 'verified'});
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                          child: const Text("Approve ✔", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                      ],
                    )
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryStripBanner(int closed, int pending, int unpaid) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBannerNode("Closed Cases", closed.toString(), const Color(0xFF10B981)),
          _buildBannerNode("Awaiting Audit", pending.toString(), Colors.orangeAccent),
          _buildBannerNode("Unpaid Risks", unpaid.toString(), Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildBannerNode(String txt, String val, Color col) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: col)),
        const SizedBox(height: 2),
        Text(txt, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color elementColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))), 
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: elementColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: elementColor, size: 22),
          )
        ],
      ),
    );
  }
}