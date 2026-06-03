import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScannerView extends StatefulWidget {
  const ScannerView({super.key});

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  bool isScanning = true;
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  void _verifyTicket(String ticketId) async {
    if (ticketId.isEmpty) return;
    setState(() => isScanning = false); 

    try {
      // 1. Fetch raw individual ticket registry row allocations bounds mapping pipeline
      var ticketDoc = await FirebaseFirestore.instance.collection('tickets').doc(ticketId).get();

      if (!ticketDoc.exists) {
        _showResult(const Color(0xFFEF4444), "INVALID TICKET ❌", "This security code pattern was not found in Event Easee registry logs.");
        return;
      }

      var ticketData = ticketDoc.data() as Map<String, dynamic>;
      String parentEventId = ticketData['eventId'] ?? '';

      // 2. Fetch the root event meta logs sheet to enforce verification authority configurations
      var eventDoc = await FirebaseFirestore.instance.collection('ticketed_events').doc(parentEventId).get();

      if (!eventDoc.exists) {
        _showResult(const Color(0xFFEF4444), "EVENT EXPIRED 🛑", "The associated host matrix for this ticket no longer references an active database context.");
        return;
      }

      var eventData = eventDoc.data() as Map<String, dynamic>;
      String absoluteOrganizerId = eventData['organizerId'] ?? '';

      // 🛡️ STRICT ISOLATION GUARD: Verifies if current device belongs to the authentic event organizer
      if (absoluteOrganizerId != _currentUid) {
        _showResult(
          const Color(0xFF7F1D1D), 
          "SECURITY EXCLUSION 🔒", 
          "Access Denied: You are not the authorized creator of this event. Only the specific host can check in registered guests."
        );
        return;
      }

      // 3. Status Lifecycle Verification Phase
      bool alreadyUsed = ticketData['isScanned'] ?? false;
      if (alreadyUsed) {
        _showResult(const Color(0xFFF59E0B), "DOUBLE ENTRY DETECTED ⚠️", "Ticket Void: This attendee credentials vector has already checked in.");
      } else {
        // Safe lock: Invalidate transaction instantly to block bypass paths duplication
        await FirebaseFirestore.instance.collection('tickets').doc(ticketId).update({'isScanned': true});
        _showResult(const Color(0xFF10B981), "VERIFIED ENTRY ✔️", "Welcome! Guest identification approved. Allocation ledger sequence synced.");
      }

    } catch (e) {
      _showResult(Colors.black, "ERROR ENCOUNTERED", "Processing subsystem failure: ${e.toString()}");
    }
  }

  void _showResult(Color color, String title, String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () { 
              Navigator.pop(context); 
              setState(() => isScanning = true); 
            }, 
            child: const Text("Resume Scanner", style: TextStyle(fontWeight: FontWeight.bold))
          )
        ]
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Operational Gate Scanner", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: isScanning 
        ? Stack(
            children: [
              MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty && isScanning) {
                    _verifyTicket(barcodes.first.rawValue ?? "");
                  }
                }
              ),
              // High fidelity overlay target visual bounding boxes layout frame vectors
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF6366F1), width: 3),
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.black.withOpacity(0.1)
                  ),
                ),
              ),
            ],
          )
        : const Center(child: CircularProgressIndicator()),
    );
  }
}