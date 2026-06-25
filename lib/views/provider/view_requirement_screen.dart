import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🚀 FIXED SYSTEM ROUTE: Connected directly to your active billing file
import 'place_bid_screen.dart'; 

class ViewRequirementScreen extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const ViewRequirementScreen({
    super.key,
    required this.eventId,
    required this.eventData,
  });

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Date Pending';
    if (timestamp is Timestamp) {
      DateTime dt = timestamp.toDate();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    }
    return timestamp.toString();
  }

  @override
  Widget build(BuildContext context) {
    String title = eventData['title'] ?? 'Custom Requirement Post';
    String description = eventData['description'] ?? 'No description provided.';
    String budget = (eventData['budget'] ?? 'Negotiable').toString();
    String status = (eventData['status'] ?? 'open').toString().toUpperCase();
    String location = eventData['location'] ?? 'Not Specified';
    String dateRange = eventData['eventDate'] ?? 'Timeline Unspecified';

    bool isOpen = status.toLowerCase() == 'open';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Requirement Details", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // MAIN METRICS CORE BOARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("STATUS: $status", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isOpen ? Colors.amber[800] : Colors.green)),
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), height: 1.2)),
                  const Divider(height: 30),
                  _buildMetricsRow(Icons.account_balance_wallet_outlined, "Budget Allocation", "Rs. $budget", valueColor: const Color(0xFF6366F1)),
                  const SizedBox(height: 16),
                  _buildMetricsRow(Icons.location_on_outlined, "Venue Location", location),
                  const SizedBox(height: 16),
                  _buildMetricsRow(Icons.calendar_today_outlined, "Event Date", dateRange),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // DESCRIPTION CARD
            const Text("FULL DESCRIPTION", style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Text(description, style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.5)),
            ),
            
            const SizedBox(height: 35),
            
            // ================= 🚀 FIXED ACTIVE NAVIGATION HOOK =================
            if (isOpen) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.gavel_rounded, size: 20),
                label: const Text("Bid Now", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: const Color(0xFF6366F1), 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () {
                  // 🚀 ACTIVE REDIRECTION ROUTE: Transfers state maps parameters directly to your bidding input form
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlaceBidScreen(
                        eventId: eventId,
                        eventTitle: title,
                      ),
                    ),
                  );
                },
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text("Bidding is closed for this post.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF475569)),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor ?? const Color(0xFF334155))),
          ],
        ),
      ],
    );
  }
}