import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class GuestListScreen extends StatefulWidget {
  final String eventId;
  const GuestListScreen({super.key, required this.eventId});

  @override
  State<GuestListScreen> createState() => _GuestListScreenState();
}

class _GuestListScreenState extends State<GuestListScreen> {

  ImageProvider _getScreenshotImageProvider(String source) {
    if (source.startsWith('data:image') && source.contains('base64,')) {
      try {
        String cleanBase64 = source.split('base64,')[1];
        return MemoryImage(base64Decode(cleanBase64));
      } catch (_) {}
    }
    return const NetworkImage('https://placehold.co/600x400/png?text=Invalid+Screenshot+Data');
  }

  void _updateTicketStatus(BuildContext context, String ticketId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('tickets') 
          .doc(ticketId)
          .update({
        'status': newStatus,
        'verifiedAt': FieldValue.serverTimestamp(),
      });
      
      if (context.mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Ticket request marked as ${newStatus.toUpperCase()} successfully!"),
            backgroundColor: newStatus == 'verified' ? const Color(0xFF10B981) : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error changing state matrix: $e")));
      }
    }
  }

  // 🚀 DETAILS DIALOG PANEL: Renders all static parameters & dynamic host forms data maps
  void _showParticipantApprovalSheet(BuildContext context, String docId, Map<String, dynamic> data) {
    String currentStatus = data['status'] ?? 'pending';
    String screenshotPayload = data['paymentScreenshot'] ?? '';
    Map<String, dynamic> responses = data['responses'] ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Attendee Dossier Link", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: currentStatus == 'verified' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          currentStatus.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11, 
                            fontWeight: FontWeight.bold, 
                            color: currentStatus == 'verified' ? Colors.green[800] : Colors.amber[800]
                          ),
                        ),
                      )
                    ],
                  ),
                  const Divider(height: 30),
                  
                  _detailRow(Icons.person_outline, "Full Identity Name", data['buyerName'] ?? 'Attendee'),
                  _detailRow(Icons.email_outlined, "Registered Email Address", data['buyerEmail'] != '' ? data['buyerEmail'] : 'N/A'),
                  _detailRow(Icons.phone_android_outlined, "Mobile Contact Vector", data['buyerPhone'] ?? 'N/A'),
                  _detailRow(Icons.confirmation_number_outlined, "Allocated Ticket Type", data['ticketType'] ?? 'Standard Ticket'),
                  
                  // 🚀 DYNAMIC QUESTIONS LOG VIEWER LAYER
                  if (responses.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      child: Text("Dynamic Registration Responses:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4F46E5))),
                    ),
                    ...responses.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                            Text(entry.value.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                    )),
                  ],

                  const SizedBox(height: 15),
                  const Text("Uploaded Payment Proof Receipt:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                  const SizedBox(height: 12),

                  if (screenshotPayload.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image(
                          image: _getScreenshotImageProvider(screenshotPayload),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: const Center(child: Text("No verification payment screenshot attached.", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500))),
                    )
                  ],

                  const SizedBox(height: 35),
                  if (currentStatus == 'pending') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text("Decline Request", style: TextStyle(fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => _updateTicketStatus(context, docId, 'declined'),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text("Verify & Approve", style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            onPressed: () => _updateTicketStatus(context, docId, 'verified'),
                          ),
                        ),
                      ],
                    )
                  ] else ...[
                    Center(
                      child: Text(
                        "This transaction request was processed as [${currentStatus.toUpperCase()}].",
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    )
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6366F1), size: 20),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text("Organizer Portal: Guest Lists", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Color(0xFF6366F1),
            labelColor: Color(0xFF6366F1),
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: "Pending Actions", icon: Icon(Icons.pending_actions_rounded)),
              Tab(text: "Approved Lineup", icon: Icon(Icons.assignment_turned_in_rounded)),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tickets') 
              .where('eventId', isEqualTo: widget.eventId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            var allDocs = snapshot.data!.docs;

            var pendingDocs = allDocs.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'pending').toList();
            var verifiedDocs = allDocs.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'verified').toList();

            return TabBarView(
              children: [
                // 🛑 TAB 1: PENDING APPROVALS
                pendingDocs.isEmpty
                    ? const Center(child: Text("No verification queues pending evaluation logs.", style: TextStyle(color: Colors.grey, fontSize: 12)))
                    : _buildGuestListSegment(pendingDocs),

                // 🟢 TAB 2: APPROVED ATTENDEES (Clean & Simple)
                verifiedDocs.isEmpty
                    ? const Center(child: Text("No approved guests located on the live configuration.", style: TextStyle(color: Colors.grey, fontSize: 12)))
                    : _buildGuestListSegment(verifiedDocs),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGuestListSegment(List<DocumentSnapshot> segmentDocs) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: segmentDocs.length,
      itemBuilder: (context, index) {
        var doc = segmentDocs[index];
        var data = doc.data() as Map<String, dynamic>;
        String curStatus = data['status'] ?? 'pending';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: ListTile(
            onTap: () => _showParticipantApprovalSheet(context, doc.id, data),
            leading: CircleAvatar(
              backgroundColor: curStatus == 'verified' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
              child: Icon(
                curStatus == 'verified' ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                color: curStatus == 'verified' ? Colors.green : Colors.amber,
                size: 20,
              ),
            ),
            title: Text(data['buyerName'] ?? 'Attendee Name', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            subtitle: Text("Phone: ${data['buyerPhone'] ?? 'N/A'}", style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
          ),
        );
      },
    );
  }
}