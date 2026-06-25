import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'dart:convert';

class TicketReceiptScreen extends StatefulWidget {
  final Map<String, dynamic> eventData; 
  final Map<String, dynamic> ticketData; 

  const TicketReceiptScreen({
    super.key,
    required this.eventData,
    required this.ticketData,
  });

  @override
  State<TicketReceiptScreen> createState() => _TicketReceiptScreenState();
}

class _TicketReceiptScreenState extends State<TicketReceiptScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  void _downloadTicketAsImage() async {
    try {
      String ticketDocId = widget.ticketData['ticketId'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = "Ticket_$ticketDocId.png";

      if (kIsWeb) {
        final Uint8List? imageBytes = await _screenshotController.capture();
        if (imageBytes != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: Color(0xFF10B981),
                content: Text("Ticket Pass downloaded via Browser Downloads!"),
              ),
            );
          }
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        await _screenshotController.captureAndSave(
          directory.path,
          fileName: fileName,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFF10B981),
              content: Text("Ticket Pass downloaded safely to Documents!"),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Download Error: ${e.toString()}"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // 🚀 NEW FEATURE: DELETE TICKET TRANSACTION ENGINE WITH CONFIRMATION DIALOGUE
  void _confirmAndCancelTicket(BuildContext context, String ticketId) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("Cancel Ticket", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          "Are you sure you want to delete this ticket pass record? This action will permanently remove your registration ledger.",
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text("Keep Ticket", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              try {
                // Delete from Firestore node
                await FirebaseFirestore.instance.collection('tickets').doc(ticketId).delete();
                
                if (context.mounted) {
                  Navigator.pop(dCtx); // Close popup dialog windows
                  Navigator.pop(context); // Jump backward out of details screen safely
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Ticket record successfully deleted from engine!"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("System deletion error: $e")));
                }
              }
            },
            child: const Text("Delete Pass", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  ImageProvider _getScreenshotImageProvider(String source) {
    if (source.startsWith('data:image') && source.contains('base64,')) {
      try {
        String cleanBase64 = source.split('base64,')[1];
        return MemoryImage(base64Decode(cleanBase64));
      } catch (_) {}
    }
    return const NetworkImage('https://placehold.co/600x400/png?text=Receipt+Screenshot');
  }

  @override
  Widget build(BuildContext context) {
    String ticketId = widget.ticketData['ticketId'] ?? 'NO-ID';
    String eName = widget.ticketData['eventName'] ?? (widget.eventData['eventName'] ?? 'Ticketed Event');
    String shortId = widget.eventData['shortId'] ?? 'EV-MAIN';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), 
      appBar: AppBar(
        title: const Text("Digital Pass Ledger", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.5)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: true,
        actions: [
          // 🚀 ACTION HOOK: Native delete vector attached straight to system hooks
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
            tooltip: "Cancel & Delete Registration Pass",
            onPressed: () => _confirmAndCancelTicket(context, ticketId),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('tickets').doc(ticketId).snapshots(),
        builder: (context, snapshot) {
          String liveStatus = widget.ticketData['status'] ?? 'pending';
          String screenshotPayload = widget.ticketData['paymentScreenshot'] ?? '';
          String gName = widget.ticketData['buyerName'] ?? (widget.ticketData['guestName'] ?? 'Guest');
          String gPhone = widget.ticketData['buyerPhone'] ?? (widget.ticketData['guestPhone'] ?? 'N/A');
          String gEmail = widget.ticketData['buyerEmail'] ?? 'N/A';

          if (snapshot.hasData && snapshot.data!.exists) {
            var liveData = snapshot.data!.data() as Map<String, dynamic>;
            liveStatus = liveData['status'] ?? 'pending';
            screenshotPayload = liveData['paymentScreenshot'] ?? '';
            gName = liveData['buyerName'] ?? gName;
            gPhone = liveData['buyerPhone'] ?? gPhone;
            gEmail = liveData['buyerEmail'] ?? gEmail;
          }

          Color statusColor = const Color(0xFFFEF3C7); 
          Color textColor = const Color(0xFFB45309); 
          IconData statusIcon = Icons.hourglass_top_rounded;

          if (liveStatus == 'verified') {
            statusColor = const Color(0xFFDCFCE7); 
            textColor = const Color(0xFF166534); 
            statusIcon = Icons.check_circle_rounded;
          } else if (liveStatus == 'declined') {
            statusColor = const Color(0xFFFEE2E2); 
            textColor = const Color(0xFF991B1B); 
            statusIcon = Icons.cancel_rounded;
          }

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440), 
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: textColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, color: textColor, size: 26),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("STATUS: ${liveStatus.toUpperCase()}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 0.5)),
                                const SizedBox(height: 2),
                                Text(
                                  liveStatus == 'pending'
                                      ? "Host payment proof verify kar raha hai."
                                      : liveStatus == 'verified'
                                          ? "Approved! Pass gates par scanned hone ke liye active hai."
                                          : "Payment refuse hone ki wajah se decline kiya gaya hai.",
                                  style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.8), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Screenshot(
                      controller: _screenshotController,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle)),
                                      const SizedBox(width: 8),
                                      const Text("OFFICIAL ATTENDEE PASS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Color(0xFF6366F1))),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                                    child: Text("ID: $shortId", style: const TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                                  )
                                ],
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Text(eName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: -0.8)),
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                              child: Divider(color: Color(0xFFF1F5F9), thickness: 1.5, height: 1),
                            ),

                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 5, child: _buildDetailColumn("ATTENDEE NAME", gName)),
                                      const SizedBox(width: 16),
                                      Expanded(flex: 5, child: _buildDetailColumn("GUEST PHONE", gPhone)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 5, child: _buildDetailColumn("EMAIL ADDRESS", gEmail)),
                                      const SizedBox(width: 16),
                                      Expanded(flex: 5, child: _buildDetailColumn("TICKET HASH", ticketId)),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Container(width: 10, height: 20, decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.only(topRight: Radius.circular(10), bottomRight: Radius.circular(10)))),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Flex(
                                        direction: Axis.horizontal,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: List.generate(
                                          (constraints.constrainWidth() / 10).floor(),
                                          (_) => SizedBox(width: 6, height: 1.5, child: DecoratedBox(decoration: BoxDecoration(color: Colors.grey[300]))),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Container(width: 10, height: 20, decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)))),
                              ],
                            ),
                            const SizedBox(height: 20),

                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                                ),
                                child: QrImageView(
                                  data: ticketId,
                                  version: QrVersions.auto,
                                  size: 130.0,
                                  gapless: false,
                                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0F172A)),
                                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0F172A)),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            const Center(
                              child: Text("Scan at entrance gate for instant validation", style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            ),

                            if (screenshotPayload.isNotEmpty) ...[
                              const Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12), child: Divider(height: 1)),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 4),
                                child: Text("YOUR SUBMITTED PAYMENT PROOF:", style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w800)),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 20.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 100,
                                    width: double.infinity,
                                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0))),
                                    child: Image(image: _getScreenshotImageProvider(screenshotPayload), fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 24),
                            ]
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        const SizedBox(height: 4),
        Text(
          value, 
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155), height: 1.2), 
          maxLines: 2, 
          overflow: TextOverflow.ellipsis
        ),
      ],
    );
  }
}