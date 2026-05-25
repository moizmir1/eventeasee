import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TicketView extends StatelessWidget {
  final String ticketId;
  final String eventName;

  const TicketView({super.key, required this.ticketId, required this.eventName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Your Ticket")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(eventName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            QrImageView(
              data: ticketId,
              version: QrVersions.auto,
              size: 250.0,
            ),
            const SizedBox(height: 20),
            const Text("Show this QR code at the event gate"),
          ],
        ),
      ),
    );
  }
}