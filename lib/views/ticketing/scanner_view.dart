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
      // 1. Fetch Ticket Data
      var ticketDoc = await FirebaseFirestore.instance.collection('tickets').doc(ticketId).get();

      if (!ticketDoc.exists) {
        _showResult(const Color(0xFFEF4444), "INVALID TICKET ❌", "This ticket ID does not exist.");
        return;
      }

      var ticketData = ticketDoc.data() as Map<String, dynamic>;
      
      // 2. Validate Ownership
      String parentEventId = ticketData['eventId'] ?? '';
      var eventDoc = await FirebaseFirestore.instance.collection('ticketed_events').doc(parentEventId).get();

      if (!eventDoc.exists || (eventDoc.data() as Map<String, dynamic>)['organizerId'] != _currentUid) {
        _showResult(const Color(0xFF7F1D1D), "SECURITY EXCLUSION 🔒", "Access Denied: You are not the organizer.");
        return;
      }

      // 3. Status Validation (Accept 'approved' OR 'verified')
      String ticketStatus = ticketData['status'] ?? 'pending';
      if (ticketStatus != 'approved' && ticketStatus != 'verified') {
        _showResult(
          const Color(0xFFEF4444), 
          "DECLINED: NOT VALID 🚫", 
          "Ticket status is '$ticketStatus'. Only approved or verified tickets are allowed."
        );
        return;
      }

      // 4. Duplicate Entry Check
      bool alreadyUsed = ticketData['isScanned'] ?? false;
      if (alreadyUsed) {
        _showResult(
          const Color(0xFFF59E0B), 
          "DUPLICATE ENTRY DETECTED ⚠️", 
          "Alert: This ticket was already verified and scanned previously!"
        );
      } else {
        // SUCCESS: Mark as scanned
        await FirebaseFirestore.instance.collection('tickets').doc(ticketId).update({'isScanned': true});
        _showResult(
          const Color(0xFF10B981), 
          "ENTRY SUCCESSFUL ✔️", 
          "Welcome! Guest identification approved."
        );
      }

    } catch (e) {
      _showResult(Colors.black, "ERROR ENCOUNTERED", "System failure: ${e.toString()}");
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
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(foregroundColor: color),
            onPressed: () { 
              Navigator.pop(context); 
              setState(() => isScanning = true); 
            }, 
            child: const Text("Resume Scanner")
          )
        ]
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Operational Gate Scanner")),
      body: isScanning 
        ? MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && isScanning) {
                _verifyTicket(barcodes.first.rawValue ?? "");
              }
            }
          )
        : const Center(child: CircularProgressIndicator()),
    );
  }
}