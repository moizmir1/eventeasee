import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScannerView extends StatefulWidget {
  const ScannerView({super.key});

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  bool isScanning = true;

  void _verifyTicket(String ticketId) async {
    setState(() => isScanning = false); 

    // Note: This scans the 'tickets' collection (Individual QR codes)
    var doc = await FirebaseFirestore.instance.collection('tickets').doc(ticketId).get();

    if (doc.exists) {
      bool alreadyUsed = doc.data()?['isScanned'] ?? false;
      if (alreadyUsed) {
        _showResult(Colors.orange, "ALREADY USED", "This guest has already entered.");
      } else {
        await FirebaseFirestore.instance.collection('tickets').doc(ticketId).update({'isScanned': true});
        _showResult(Colors.green, "VERIFIED ✔️", "Entry permitted.");
      }
    } else {
      _showResult(Colors.red, "INVALID TICKET", "This code was not found in our records.");
    }
  }

  void _showResult(Color color, String title, String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: color,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        actions: [TextButton(onPressed: () { Navigator.pop(context); setState(() => isScanning = true); }, child: const Text("OK", style: TextStyle(color: Colors.white)))]
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Tickets")),
      body: isScanning 
        ? MobileScanner(onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              _verifyTicket(barcodes.first.rawValue ?? "");
            }
          })
        : const Center(child: CircularProgressIndicator()),
    );
  }
}